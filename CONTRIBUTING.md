# Contributing

Thanks for looking at Pterodactyl Mobile — contributions from humans and AI coding agents are both welcome.

1. **Setup**: follow [README.md](README.md) to get Flutter, the Android SDK, and the app itself running.
2. **Conventions**: read [AGENTS.md](AGENTS.md) — it covers the project's minimal/lazy coding philosophy, file layout, the Pterodactyl API surface, security norms, and current scope cuts. This applies whether you're a person or an agent.
3. **Before opening a PR**: run `flutter analyze` and `flutter test`, and make sure both are clean. Add a test for any non-trivial new logic.
4. **Scope**: keep PRs focused. If you want to tackle something on the roadmap list in AGENTS.md (file manager, multi-panel support, iOS, etc.), open an issue first to discuss approach before investing a lot of time.
5. **Security**: never commit a real panel URL or API key (including in tests, screenshots, or issue reports). If you find a security issue, please open an issue describing it — there's no bounty program, but it'll get looked at.

Bug reports and feature requests are welcome as GitHub issues.
