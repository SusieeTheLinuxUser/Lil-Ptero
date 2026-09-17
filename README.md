<p align="center">
  <img src="assets/icon/icon.png" width="140" alt="Pterodactyl Mobile logo">
</p>

# Pterodactyl Mobile

A free, open-source Android app for viewing and controlling Minecraft servers hosted behind any [Pterodactyl](https://pterodactyl.io/) panel — no matter who's hosting them.

Connect with your panel URL and a personal Client API key (generated in your Pterodactyl account settings), then:

- See your servers and their live resource usage (CPU, memory, disk)
- Start / restart / stop / kill a server
- Watch the live console and send commands

No account with us, no backend of ours in the middle — the app talks directly to your panel's API.

## Status

v0.1.2 shipped: server list, resource stats, power controls, live console, dark theme with accent presets, and per-ABI Android APKs. Android only for now.

## Getting started (development)

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) and the Android SDK/toolchain (`flutter doctor` should report Android as ready).
2. From this directory, generate the Android platform scaffold (only needs to be done once, it won't touch the existing `lib/`, `test/`, or `pubspec.yaml`):
   ```bash
   flutter create --platforms=android .
   ```
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run the unit tests:
   ```bash
   flutter test
   ```
5. Run the app on a connected device or emulator:
   ```bash
   flutter run
   ```

## Installing

- **GitHub Releases**: grab the latest signed APK from [Releases](https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases) and sideload it.
- **F-Droid**: [submitted](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/49236), with reviewer-requested ABI splits and reproducible-build metadata prepared; not yet live in the official repo. See [fdroid/README.md](fdroid/README.md) for the current status and verification evidence.

## Getting a Client API key

In your Pterodactyl panel, go to **Account Settings → API Credentials** and create a new Client API key. Use that (not an Application/admin key) along with your panel's base URL (e.g. `https://panel.example.com`) in the app's setup screen.

## Contributing

Humans and AI coding agents both welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) to get started and [AGENTS.md](AGENTS.md) for the project's conventions.

## License

MIT — see [LICENSE](LICENSE).
