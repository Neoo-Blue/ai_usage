import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'models.dart';
import 'providers.dart';

class CapturedCredential {
  final ProviderId provider;
  final Map<String, String> bundle; // cookieName -> value, goes to the vault
  final String? remoteUserId;
  final String? email;
  final String? plan;

  CapturedCredential({
    required this.provider,
    required this.bundle,
    this.remoteUserId,
    this.email,
    this.plan,
  });
}

// Fresh login each time. We clear this provider's cookie jar before and after
// capture, so a previously connected account of the same provider never leaks
// in. Isolation of the saved credential happens in the vault, keyed by UUID.
class CaptureScreen extends StatefulWidget {
  final ProviderAuthConfig config;
  const CaptureScreen({super.key, required this.config});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _cookies = CookieManager.instance();
  InAppWebViewController? _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _cookies.deleteCookies(url: WebUri(widget.config.origin));
  }

  Future<void> _tryCapture() async {
    if (_done || _controller == null) return;
    final origin = WebUri(widget.config.origin);

    // getCookies reads the native cookie store, which includes HttpOnly cookies
    // like the session token. document.cookie cannot see those.
    final cookies = await _cookies.getCookies(url: origin);
    final bundle = <String, String>{};
    for (final name in widget.config.sessionCookieNames) {
      final match = cookies.where((c) => c.name == name);
      if (match.isNotEmpty) bundle[name] = match.first.value.toString();
    }

    final hasAll = widget.config.sessionCookieNames.every(bundle.containsKey);
    if (!hasAll) return; // not signed in yet

    // Grab cf_clearance too so the sync layer can replay past Cloudflare.
    final cf = cookies.where((c) => c.name == 'cf_clearance');
    if (cf.isNotEmpty) bundle['cf_clearance'] = cf.first.value.toString();

    String? remoteUserId, email, plan;
    final probe = widget.config.identityProbeJs;
    if (probe != null) {
      final res = await _controller!.callAsyncJavaScript(functionBody: probe);
      final v = res?.value;
      if (v is Map && v['ok'] == true) {
        remoteUserId = v['remoteUserId'] as String?;
        email = v['email'] as String?;
        plan = v['plan'] as String?;
      }
    }

    _done = true;
    await _cookies.deleteCookies(url: origin);
    if (!mounted) return;
    Navigator.pop(
      context,
      CapturedCredential(
        provider: widget.config.id,
        bundle: bundle,
        remoteUserId: remoteUserId,
        email: email,
        plan: plan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect ${widget.config.displayName}'),
        actions: [
          TextButton(
            onPressed: _tryCapture,
            child: const Text('I am signed in'),
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.config.loginUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          thirdPartyCookiesEnabled: true,
        ),
        onWebViewCreated: (c) => _controller = c,
        onLoadStop: (_, __) => _tryCapture(),
      ),
    );
  }
}
