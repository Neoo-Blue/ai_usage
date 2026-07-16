import 'models.dart';

// Per provider login details for the WebView capture flow. The identity probe is
// an async JS body run via callAsyncJavaScript; it returns {ok:true, ...} or {ok:false}.
class ProviderAuthConfig {
  final ProviderId id;
  final String displayName;
  final String loginUrl;
  final String origin; // where we read and clear cookies
  final List<String> sessionCookieNames;
  final String? identityProbeJs;

  const ProviderAuthConfig({
    required this.id,
    required this.displayName,
    required this.loginUrl,
    required this.origin,
    required this.sessionCookieNames,
    this.identityProbeJs,
  });
}

const Map<ProviderId, ProviderAuthConfig> providerConfigs = {
  ProviderId.openai: ProviderAuthConfig(
    id: ProviderId.openai,
    displayName: 'ChatGPT',
    loginUrl: 'https://chatgpt.com/',
    origin: 'https://chatgpt.com',
    sessionCookieNames: ['__Secure-next-auth.session-token'],
    identityProbeJs: '''
      try {
        const r = await fetch('/api/auth/session', { credentials: 'include' });
        if (!r.ok) return { ok: false };
        const j = await r.json();
        return {
          ok: true,
          remoteUserId: (j.user && j.user.id) || null,
          email: (j.user && j.user.email) || null,
          plan: (j.user && j.user.plan) || 'Plus'
        };
      } catch (e) { return { ok: false }; }
    ''',
  ),
  ProviderId.anthropic: ProviderAuthConfig(
    id: ProviderId.anthropic,
    displayName: 'Claude',
    loginUrl: 'https://claude.ai/login',
    origin: 'https://claude.ai',
    sessionCookieNames: ['sessionKey'],
    identityProbeJs: '''
      try {
        const r = await fetch('/api/organizations', { credentials: 'include' });
        if (!r.ok) return { ok: false };
        const orgs = await r.json();
        const org = Array.isArray(orgs) && orgs.length ? orgs[0] : null;
        return {
          ok: true,
          remoteUserId: org ? org.uuid : null,
          email: null,
          plan: org ? (org.billing_type || null) : null
        };
      } catch (e) { return { ok: false }; }
    ''',
  ),
  ProviderId.google: ProviderAuthConfig(
    id: ProviderId.google,
    displayName: 'Gemini',
    loginUrl: 'https://gemini.google.com/app',
    origin: 'https://google.com',
    sessionCookieNames: ['__Secure-1PSID', '__Secure-1PSIDTS', '__Secure-1PSIDCC'],
    identityProbeJs: null,
  ),
};
