# Development

## Architecture at a glance

- **Framework:** Flutter, single UI codebase. The native home screen widget (Jetpack Glance on Android, WidgetKit on iOS) is planned; the Dart data layer that feeds it is already in place.
- **Storage:** secrets live in `flutter_secure_storage` (Keychain / EncryptedSharedPreferences), keyed by a client UUID. The database never holds a token or cookie.
- **Local database:** `sqflite` with raw SQL (`accounts`, `metric_snapshots`, `provider_health`, `widget_configs`). Chosen over Drift for this cut so CI needs no code generation step; the schema is identical to the Drift design.
- **Sync engine:** typed errors, retry with backoff, and a persisted per provider circuit breaker. API key accounts read live rate limit headers; subscription accounts fetch through a headless WebView so they clear Cloudflare, which blocks raw HTTP clients by TLS fingerprint.

## Build the APK

CI builds on every push to `main` and on tags (`.github/workflows/build-apk.yml`). There is no committed `android/` folder; CI regenerates it with `flutter create` so the Gradle scaffold always matches the pinned toolchain.

Locally (needs the Flutter SDK):

```
flutter create --org com.example --project-name ai_usage --platforms=android .
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Two build notes worth knowing:

- **Flutter is pinned to 3.24.5 in CI.** The newest Android Gradle Plugin rejects a proguard reference that `flutter_inappwebview` still uses, so the pin keeps the plugin building.
- **The release manifest needs the `INTERNET` permission.** `flutter create` only adds it to debug and profile builds, so the release APK has no network access unless it is added. CI injects the permission after `flutter create`; without it the WebView renders blank and sync fails.

## Test the private endpoints without building

The fastest way to check whether an account exposes usage data is a browser console, which is already past Cloudflare:

```js
// at https://claude.ai
(async () => {
  const r = await fetch('/api/organizations', { credentials: 'include' });
  console.log(r.status, JSON.stringify(await r.json(), null, 2));
})();
```

```js
// at https://chatgpt.com
(async () => {
  const s = await fetch('/api/auth/session', { credentials: 'include' });
  console.log(s.status, await s.json());
})();
```

To find a live usage count, keep DevTools on the Network tab, use the app until the limit indicator appears, and note the XHR that carries it. That path goes into the subscription client's usage seam.

## Known constraints

- Subscription sync runs a WebView because chatgpt.com and claude.ai sit behind Cloudflare, which blocks raw HTTP clients. This is heavier than plain HTTP and is best run while the app is in the foreground.
- There is no stable public endpoint that returns a consumer messages remaining count. The clients read plan and identity reliably and leave the live count as a discovery seam.
- Dependency versions in `pubspec.yaml` target the pinned Flutter. If `flutter pub get` reports a conflict, bump the offending package.

## Deferred

- The native Glance and WidgetKit widget, plus the six theme engine.
- Drift (the schema already matches the sqflite tables).
- The volatile subscription usage endpoints.
