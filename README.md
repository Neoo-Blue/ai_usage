# AI Usage

Track your AI subscription and API usage limits in one place, with a configurable, themeable home screen widget. Built for Claude, ChatGPT, and Gemini, plus their developer APIs.

## Download

- **Android:** the latest APK on the [Releases page](https://github.com/Neoo-Blue/ai_usage/releases/latest). Enable "install unknown apps" for your browser or file manager, then open the file.
- **iOS (sideload):** the unsigned build at [ios-0.5.1](https://github.com/Neoo-Blue/ai_usage/releases/tag/ios-0.5.1). Install it with Sideloadly or AltStore using your Apple ID (steps in [DEVELOPMENT.md](DEVELOPMENT.md)). The app works on a free Apple ID; the iOS home screen widget needs a paid Apple Developer account, because widget data sharing on iOS uses App Groups that free accounts cannot create.

## What it does

- **Multiple providers and multiple accounts each.** Connect a personal and a work ChatGPT, a Claude account, and more. Two accounts on the same provider never overwrite each other.
- **Two account kinds:**
  - Subscription: sign in through a secure in app browser. The app keeps only your session, on your device.
  - Developer API key: paste a key for live remaining tokens and requests straight from the provider.
- **Real usage, pulled automatically.** For a Claude subscription it reads your current session percent, weekly all models percent, and per model weekly percents, each with its reset time, and shows them as progress bars that match Claude's own usage screen. No API key, no configuration.
- **Everything stays on device.** Your logins live in the system keychain, never in a database and never uploaded.

## Home screen widget

- **Per widget setup:** choose the account, one of seven themes, and what the header shows (nickname only, plan, or email).
- **Seven themes:** Minimalist, Elegant, Futuristic (neon glow), Neumorphic, Retro, Adaptive (Material You), and Caution (black with yellow and black hazard stripe bars). The widget renders as a Flutter image, so the themes are fully custom.
- **Resizable to any size**, and it drops to fewer bars when the widget is short.
- **A refresh button** and a **preview** in the widget picker.

## Notes and limits

- There is no plain "messages remaining" count for a consumer Claude plan, so the app reads the utilization percentages Claude exposes at its own usage endpoint, using your existing session.
- The widget refresh opens the app to sync, because fetching fresh usage needs a real browser session to clear Cloudflare; there is no fully silent background refresh.

## Privacy

Your provider logins never leave the device. The app is a direct client to Claude, ChatGPT, and Gemini; there is no server of its own that it talks to.

For build, architecture, and sideload details, see [DEVELOPMENT.md](DEVELOPMENT.md).
