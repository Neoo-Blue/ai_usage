# AI Usage

Cross platform tracker for AI subscription and API usage limits. This is the first buildable cut: the multi account cookie interceptor, secure per account storage, a local database, and the sync engine (API key path returns live numbers; subscription path fetches through a WebView to get past Cloudflare).

## What is in this cut

- Multi account, multi provider connect flow (OpenAI, Anthropic, Google).
- WebView cookie interception with per account isolation keyed by UUID.
- Developer API key accounts (Anthropic, OpenAI) that read live rate limit headers.
- Sync engine with typed errors, retry with backoff, and a persisted per provider circuit breaker.
- App Group mirror write for the future iOS widget configuration list.

## What is deliberately not here yet

- The native home screen widget (Jetpack Glance on Android, WidgetKit on iOS). It was left out of the first build on purpose so an unverified Kotlin or Gradle module cannot break the APK. The Dart data layer that feeds it is already in place.
- Drift. This cut uses sqflite with raw SQL so there is no code generation step in CI. The schema matches the Drift design one to one.

## Get an installable APK (the download link)

There is no committed `android/` folder. CI regenerates it so the Gradle scaffold always matches the toolchain. To produce an APK:

1. Push this project to a GitHub repo.
2. The workflow at `.github/workflows/build-apk.yml` runs on push to `main` and on manual dispatch.
3. Open the workflow run and download the `ai_usage_apk` artifact. That artifact is your installable APK.
4. To publish a public release link instead, push a tag: `git tag v0.1.0 && git push --tags`. The workflow attaches the APK to a GitHub Release.

To build locally instead (needs the Flutter SDK):

```
flutter create --org com.example --project-name ai_usage --platforms=android .
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Test the endpoints without building anything

The fastest check of whether your accounts expose usage data is a browser console, which is already past Cloudflare:

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

## Known constraints

- The subscription sync runs a WebView because chatgpt.com and claude.ai are behind Cloudflare, which blocks raw HTTP clients by TLS fingerprint. This is heavier than plain HTTP and is best run while the app is in the foreground.
- There is no stable public endpoint that returns a consumer messages remaining count. The clients read plan and identity reliably and leave the live count as a discovery seam.
- Dependency versions in `pubspec.yaml` target a recent stable Flutter. If `flutter pub get` reports a conflict, bump the offending package; it is a one line change.
