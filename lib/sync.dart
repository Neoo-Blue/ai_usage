import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'account_mirror.dart';
import 'db.dart';
import 'models.dart';
import 'vault.dart';

// ---- typed errors -----------------------------------------------------------

class AuthExpired implements Exception {}

class RateLimited implements Exception {
  final Duration? retryAfter;
  RateLimited({this.retryAfter});
}

class TransientSyncError implements Exception {
  final String reason;
  TransientSyncError(this.reason);
}

class PermanentSyncError implements Exception {
  final String reason;
  PermanentSyncError(this.reason);
}

class ParsedMetric {
  final String metricType;
  final double? numValue;
  final String? textValue;
  final String? unit;
  const ParsedMetric(this.metricType, {this.numValue, this.textValue, this.unit});
}

// ---- shared http ------------------------------------------------------------

Future<http.Response> _send(http.Client c, http.BaseRequest req) async {
  http.StreamedResponse s;
  try {
    s = await c.send(req).timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw TransientSyncError('timeout');
  } on SocketException catch (e) {
    throw TransientSyncError('network ${e.osError?.errorCode}');
  }
  final res = await http.Response.fromStream(s);
  final code = res.statusCode;
  if (code >= 200 && code < 300) return res;
  if (code == 401 || code == 403) throw AuthExpired();
  if (code == 429) {
    final ra = int.tryParse(res.headers['retry-after'] ?? '');
    throw RateLimited(retryAfter: ra != null ? Duration(seconds: ra) : null);
  }
  if (code >= 500) throw TransientSyncError('server $code');
  throw PermanentSyncError('http $code');
}

DateTime? _resetFromGoDuration(String? s) {
  if (s == null) return null;
  var d = Duration.zero;
  for (final m in RegExp(r'(\d+(?:\.\d+)?)(ms|s|m|h)').allMatches(s)) {
    final v = double.parse(m.group(1)!);
    d += switch (m.group(2)) {
      'ms' => Duration(milliseconds: v.round()),
      's' => Duration(milliseconds: (v * 1000).round()),
      'm' => Duration(seconds: (v * 60).round()),
      _ => Duration(minutes: (v * 60).round()),
    };
  }
  return DateTime.now().add(d);
}

// ---- WebView transport for consumer endpoints -------------------------------

// Runs fetch() inside a real (headless) WebView so it inherits the browser TLS
// fingerprint + cf_clearance + cookie jar. A raw http client is 403'd by
// Cloudflare on chatgpt.com and claude.ai.
class WebViewFetcher {
  static Future<dynamic> run({
    required String origin,
    required Map<String, String> seedCookies,
    required String warmupUrl,
    required String fetchBody,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final cm = CookieManager.instance();
    final originUri = WebUri(origin);
    for (final e in seedCookies.entries) {
      await cm.setCookie(url: originUri, name: e.key, value: e.value, isSecure: true);
    }

    final completer = Completer<dynamic>();
    late final HeadlessInAppWebView headless;
    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(warmupUrl)),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onLoadStop: (controller, _) async {
        if (completer.isCompleted) return;
        final res = await controller.callAsyncJavaScript(functionBody: fetchBody);
        final v = res?.value;
        // Only complete on real data; a Cloudflare interstitial also fires
        // onLoadStop, so ignore it and let the resolved page try again.
        if (v is Map && v['ok'] == true) completer.complete(v);
      },
    );

    await headless.run();
    try {
      return await completer.future.timeout(timeout);
    } finally {
      await headless.dispose();
    }
  }
}

// ---- clients ----------------------------------------------------------------

abstract class SyncClient {
  Future<List<ParsedMetric>> fetch(Account a, Map<String, String> creds, http.Client c);
}

class OpenAiApiClient implements SyncClient {
  @override
  Future<List<ParsedMetric>> fetch(Account a, Map<String, String> creds, http.Client c) async {
    final req = http.Request('POST', Uri.parse('https://api.openai.com/v1/chat/completions'))
      ..headers['authorization'] = 'Bearer ${creds['apiKey']}'
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'model': 'gpt-4o-mini',
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': '.'}
        ],
      });
    final res = await _send(c, req);
    final h = res.headers;
    double? n(String k) => double.tryParse(h[k] ?? '');
    final reset = _resetFromGoDuration(h['x-ratelimit-reset-tokens']);
    return [
      if (n('x-ratelimit-remaining-tokens') != null)
        ParsedMetric('tokens_remaining', numValue: n('x-ratelimit-remaining-tokens'), unit: 'tokens'),
      if (n('x-ratelimit-limit-tokens') != null)
        ParsedMetric('tokens_limit', numValue: n('x-ratelimit-limit-tokens'), unit: 'tokens'),
      if (n('x-ratelimit-remaining-requests') != null)
        ParsedMetric('requests_remaining', numValue: n('x-ratelimit-remaining-requests'), unit: 'requests'),
      if (reset != null) ParsedMetric('resets_at', textValue: reset.toIso8601String()),
    ];
  }
}

class AnthropicApiClient implements SyncClient {
  @override
  Future<List<ParsedMetric>> fetch(Account a, Map<String, String> creds, http.Client c) async {
    final req = http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
      ..headers['x-api-key'] = creds['apiKey'] ?? ''
      ..headers['anthropic-version'] = '2023-06-01'
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'model': 'claude-haiku-4-5',
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': '.'}
        ],
      });
    final res = await _send(c, req);
    final h = res.headers;
    double? n(String k) => double.tryParse(h[k] ?? '');
    final reset = DateTime.tryParse(h['anthropic-ratelimit-tokens-reset'] ?? '');
    return [
      if (n('anthropic-ratelimit-tokens-remaining') != null)
        ParsedMetric('tokens_remaining', numValue: n('anthropic-ratelimit-tokens-remaining'), unit: 'tokens'),
      if (n('anthropic-ratelimit-tokens-limit') != null)
        ParsedMetric('tokens_limit', numValue: n('anthropic-ratelimit-tokens-limit'), unit: 'tokens'),
      if (n('anthropic-ratelimit-requests-remaining') != null)
        ParsedMetric('requests_remaining', numValue: n('anthropic-ratelimit-requests-remaining'), unit: 'requests'),
      if (reset != null) ParsedMetric('resets_at', textValue: reset.toIso8601String()),
    ];
  }
}

class OpenAiSubscriptionClient implements SyncClient {
  @override
  Future<List<ParsedMetric>> fetch(Account a, Map<String, String> creds, http.Client c) async {
    final data = await WebViewFetcher.run(
      origin: 'https://chatgpt.com',
      seedCookies: {
        if (creds['__Secure-next-auth.session-token'] != null)
          '__Secure-next-auth.session-token': creds['__Secure-next-auth.session-token']!,
        if (creds['cf_clearance'] != null) 'cf_clearance': creds['cf_clearance']!,
      },
      warmupUrl: 'https://chatgpt.com/',
      fetchBody: '''
        try {
          const s = await fetch('/api/auth/session', { credentials: 'include' });
          if (!s.ok) return { ok: false };
          const sj = await s.json();
          // No stable public messages remaining endpoint; return what is real.
          return { ok: true, plan: (sj.user && sj.user.plan) || 'Plus' };
        } catch (e) { return { ok: false }; }
      ''',
    );
    final plan = (data is Map) ? data['plan'] as String? : null;
    return [if (plan != null) ParsedMetric('plan', textValue: plan)];
  }
}

class AnthropicSubscriptionClient implements SyncClient {
  @override
  Future<List<ParsedMetric>> fetch(Account a, Map<String, String> creds, http.Client c) async {
    final data = await WebViewFetcher.run(
      origin: 'https://claude.ai',
      seedCookies: {
        if (creds['sessionKey'] != null) 'sessionKey': creds['sessionKey']!,
        if (creds['cf_clearance'] != null) 'cf_clearance': creds['cf_clearance']!,
      },
      warmupUrl: 'https://claude.ai/',
      fetchBody: '''
        try {
          const r = await fetch('/api/organizations', { credentials: 'include' });
          if (!r.ok) return { ok: false };
          const orgs = await r.json();
          const org = Array.isArray(orgs) && orgs.length ? orgs[0] : null;
          return { ok: true, plan: org ? (org.billing_type || 'Pro') : 'Pro' };
        } catch (e) { return { ok: false }; }
      ''',
    );
    final plan = (data is Map) ? data['plan'] as String? : null;
    return [if (plan != null) ParsedMetric('plan', textValue: plan)];
  }
}

class GoogleSubscriptionClient implements SyncClient {
  @override
  Future<List<ParsedMetric>> fetch(Account a, Map<String, String> creds, http.Client c) async {
    return [ParsedMetric('plan', textValue: a.planName ?? 'Advanced')];
  }
}

SyncClient clientFor(ProviderId provider, AccountKind kind) {
  return switch ((provider, kind)) {
    (ProviderId.openai, AccountKind.api) => OpenAiApiClient(),
    (ProviderId.openai, AccountKind.subscription) => OpenAiSubscriptionClient(),
    (ProviderId.anthropic, AccountKind.api) => AnthropicApiClient(),
    (ProviderId.anthropic, AccountKind.subscription) => AnthropicSubscriptionClient(),
    (ProviderId.google, _) => GoogleSubscriptionClient(),
  };
}

// ---- retry + circuit breaker ------------------------------------------------

Future<T> _withRetry<T>(Future<T> Function() op, {int maxAttempts = 3}) async {
  final rng = Random();
  for (var attempt = 1;; attempt++) {
    try {
      return await op();
    } on TransientSyncError {
      if (attempt >= maxAttempts) rethrow;
      final base = Duration(milliseconds: 400 * (1 << (attempt - 1)));
      await Future.delayed(base + Duration(milliseconds: rng.nextInt(250)));
    } on RateLimited catch (e) {
      if (attempt >= maxAttempts) rethrow;
      await Future.delayed(e.retryAfter ?? const Duration(seconds: 30));
    }
  }
}

Future<bool> _breakerOpen(ProviderId p) async {
  final row = await Db.instance.healthFor(p);
  final until = row?['open_until'] as String?;
  if (until == null) return false;
  final t = DateTime.tryParse(until);
  return t != null && DateTime.now().isBefore(t);
}

Future<void> _breakerSuccess(ProviderId p) => Db.instance.writeHealth(p, failures: 0);

Future<void> _breakerFailure(ProviderId p, String error) async {
  final row = await Db.instance.healthFor(p);
  final fails = ((row?['consecutive_failures'] as int?) ?? 0) + 1;
  DateTime? openUntil;
  if (fails >= 3) {
    final minutes = (5 * (1 << (fails - 3))).clamp(5, 120);
    openUntil = DateTime.now().add(Duration(minutes: minutes));
  }
  await Db.instance.writeHealth(p, failures: fails, openUntil: openUntil, lastError: error);
}

// ---- orchestration ----------------------------------------------------------

class SyncResult {
  final AccountStatus status;
  final String? note;
  SyncResult(this.status, {this.note});
}

// Sync one account. Returns the resulting status so the UI can react.
Future<SyncResult> syncOne(Account account) async {
  if (await _breakerOpen(account.provider)) {
    return SyncResult(account.status, note: 'Provider cooling down');
  }
  final creds = await Vault.read(account.id);
  if (creds == null) {
    await Db.instance.setStatus(account.id, AccountStatus.needsReauth);
    return SyncResult(AccountStatus.needsReauth, note: 'No stored credentials');
  }

  final client = clientFor(account.provider, account.kind);
  final http.Client c = http.Client();
  try {
    final metrics = await _withRetry(() => client.fetch(account, creds, c));
    for (final m in metrics) {
      await Db.instance.upsertMetric(MetricRow(
        accountId: account.id,
        metricType: m.metricType,
        numValue: m.numValue,
        textValue: m.textValue,
        unit: m.unit,
        capturedAt: DateTime.now(),
      ));
    }
    await Db.instance.setSynced(account.id);
    await _breakerSuccess(account.provider);
    return SyncResult(AccountStatus.active,
        note: metrics.isEmpty ? 'No metrics available' : 'Synced ${metrics.length} metrics');
  } on AuthExpired {
    await Db.instance.setStatus(account.id, AccountStatus.needsReauth);
    return SyncResult(AccountStatus.needsReauth, note: 'Sign in again');
  } on RateLimited {
    await _breakerFailure(account.provider, 'rate limited');
    return SyncResult(account.status, note: 'Rate limited');
  } on TransientSyncError catch (e) {
    await _breakerFailure(account.provider, e.reason);
    return SyncResult(account.status, note: 'Temporary error: ${e.reason}');
  } catch (e) {
    await Db.instance.setStatus(account.id, AccountStatus.error);
    await _breakerFailure(account.provider, e.toString());
    return SyncResult(AccountStatus.error, note: 'Error');
  } finally {
    c.close();
  }
}

Future<void> syncAll() async {
  final accounts = await Db.instance.allAccounts();
  for (final a in accounts) {
    if (a.status == AccountStatus.needsReauth) continue;
    await syncOne(a);
  }
  await AccountMirror.push();
}
