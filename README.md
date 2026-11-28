<p align="center">
  <img src="assets/icon/icon.png" width="140" alt="Pterodactyl Mobile logo">
</p>

# Pterodactyl Mobile

A free, open-source Android app for viewing and controlling Minecraft servers hosted behind any [Pterodactyl](https://pterodactyl.io/) panel — no matter who's hosting them.

Connect with your panel URL and a personal Client API key (generated in your Pterodactyl account settings), then:

- See your servers and their live resource usage (CPU, memory, disk)
- Start / restart / stop / kill a server (stop, restart and kill ask first)
- Watch the live console and send commands; it reconnects on its own if the connection drops while the server is running (after a server stop, tap Reconnect once it is back)
- Pull to refresh the server list; a failed load gets a Retry button
- Get a notification when a server stops or crashes, even with the app closed (opt-in, in Settings)
- Get a banner when a newer version is out — checked about once a day (opt-out in Settings)

No account with us, no backend of ours in the middle — the app talks directly to your panel's API.

### Background notifications

Turning on **Server status notifications** in Settings starts a background service that checks your servers every 30 seconds and notifies you when one goes offline. Android requires a permanent "Pterodactyl Mobile" notification while it runs — that's what keeps the OS from killing it; it shows the time of the last check so you can tell the watcher is alive.

Android will still stop the watcher to save power unless you allow it to run in the background. The Settings screen offers the standard exemption prompt, but **most non-Pixel phones need a second, vendor-specific toggle too** (Samsung, Xiaomi, OPPO/OnePlus, Huawei and others each bury it somewhere different). On OPPO/OnePlus, for example, it's "Allow background activity" in the phone's own battery manager, separate from the standard Android prompt. [dontkillmyapp.com](https://dontkillmyapp.com) has per-manufacturer instructions.

## Status

v0.1.4 shipped: server list, resource stats, power controls, live console, dark theme with accent presets, per-ABI Android APKs, background server-status notifications (v0.1.3+), and the check-for-updates banner. In `dev` since v0.1.4, next release: pull-to-refresh with a Retry button, a console that reconnects on its own, and screen-reader labels. Android only for now.

## Getting started (development)

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) and the Android SDK/toolchain (`flutter doctor` should report Android as ready).
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the unit tests:
   ```bash
   flutter test
   ```
4. Run the app on a connected device or emulator:
   ```bash
   flutter run
   ```

## Installing

- **GitHub Releases**: grab the latest signed APK from [Releases](https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases) and sideload it.
- **F-Droid (my own repo)**: see [Get it on my F-Droid repo](#get-it-on-my-f-droid-repo) below.

### Get it on my F-Droid repo

[![Add my F-Droid repo](https://img.shields.io/badge/F--Droid-Add%20my%20repo-1976D2?logo=f-droid&logoColor=white)](https://fdroid.link/#https://susieethelinuxuser.github.io/fdroid/repo?fingerprint=2114A3D71296AC8E8CA4A158DA5AA493E1DDB4F4A71EF173702BFAE18B71773D)

On your phone, tap the button above or scan the QR code. If F-Droid is installed it opens straight away and asks to add the repo. With Droid-ify or Neo Store, the link opens a small fdroid.link page in your browser: tap **Android Deep Link** there.

<img src="fdroid/repo-qr.png" width="180" alt="QR code that adds the Lil-Ptero F-Droid repo">

- Repo address: `https://susieethelinuxuser.github.io/fdroid/repo`
- Fingerprint: `2114A3D71296AC8E8CA4A158DA5AA493E1DDB4F4A71EF173702BFAE18B71773D`
- Direct link for any F-Droid client: `fdroidrepos://susieethelinuxuser.github.io/fdroid/repo?fingerprint=2114A3D71296AC8E8CA4A158DA5AA493E1DDB4F4A71EF173702BFAE18B71773D`

The repo serves the same signed APKs as the GitHub releases (app signing key SHA-256 `940bcf557d80048ecd1bc7f2dd02de8f0d4591592b9922ee8f1af299754d56a6`), so you can switch between the two without reinstalling. It updates by itself after each release. Source: [SusieeTheLinuxUser/fdroid](https://github.com/SusieeTheLinuxUser/fdroid).

## Getting a Client API key

In your Pterodactyl panel, go to **Account Settings → API Credentials** and create a new Client API key. Use that (not an Application/admin key) along with your panel's base URL (e.g. `https://panel.example.com`) in the app's setup screen.

## Contributing

Humans and AI coding agents both welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) to get started and [AGENTS.md](AGENTS.md) for the project's conventions.

## License

MIT — see [LICENSE](LICENSE).
