# F-Droid reviewer handoff

Use this file for the current F-Droid task instead of rereading the full project documentation.

## Current state (verified 2026-09-19 against GitLab's API, not assumed from an older summary)

- App: `dev.susiee.lilptero`, release `v0.1.2`, build number `3`. Tag `v0.1.2` = commit `9ce3dd68ca951a26017248fb97c4ba52160baf98` — re-verify with `git ls-remote --tags origin v0.1.2` before trusting any SHA written down here; the app repo's history was rewritten once already (see gotcha below) and orphaned the SHA an earlier revision of this file quoted.
- F-Droid MR: [!49236](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/49236), branch `dev.susiee.lilptero` in the `SusieeTheLinuxUser/fdroiddata` fork, currently at commit `d1d7e706`.
- **Three rounds of reviewer feedback from `linsui`, all resolved and pushed:**
  1. Follow the Flutter template, add ABI split, add `versionCodeOverride` in Gradle — done, matches their suggested snippet exactly.
  2. Add `binary:`/`AllowedAPKSigningKeys` for reproducible builds — done; all three ABI APKs rebuild byte-identical to the published ones.
  3. Pin the Flutter version (was tracking `stable`) and fix a JNI patch path that was pinned to a literal package version (`jni-1.0.3`, breaks on bump) — done: Flutter version is now extracted live from `.github/workflows/release.yml` and checked out in the srclib; the JNI sed target is the version-agnostic glob `jni-*`.
- Full F-Droid pipeline passed: `fdroid build`, `check apk`, `fdroid lint`, `fdroid rewritemeta` — https://gitlab.com/SusieeTheLinuxUser/fdroiddata/-/pipelines/2862036916
- **`linsui`'s latest reply (2026-09-18, verbatim):** "This MR is mostly ready. We'll test it later. If everything works well we'll merge it. Meantime if you release a new version please update this MR. Currently we have lots of MRs waiting for test so it may take a long time. If you'd like to help you can test those MRs and posting the result."

## Next actions

**There is nothing to do right now.** The MR is in F-Droid's queue awaiting their own testing pass — the ball is in their court — current labels are `New App`, `reproducible-builds`, `review-requested` (no `waiting-on-response`), pipeline `success`, `mergeable: true` (verified via the API 2026-09-19). Do not:
- Open a replacement MR.
- Cut a new release just to "check in" — only cut one if the app itself changes.
- Re-ping `linsui` — they explicitly said it may take a long time due to queue volume.

If a new app version ships (e.g. the background-notifications feature on `main`), update the *existing* MR: bump `fdroid/dev.susiee.lilptero.yml` (commit SHA, versionName, and re-verify reproducibility — a new release potentially changes `libapp.so`/`libdartjni.so` bytes), copy to `~/development/fdroiddata/metadata/dev.susiee.lilptero.yml`, run `fdroid rewritemeta dev.susiee.lilptero` if formatting drifts, commit, and push the same `dev.susiee.lilptero` branch. Note: a v0.1.3 with the background-notification feature is expected eventually, and it adds two Flutter plugins plus Android core-library desugaring — assume the reproducibility verification needs redoing from scratch when that happens, don't assume it still holds.

If `linsui` (or anyone) leaves new review feedback: read it via the GitLab API (`https://gitlab.com/api/v4/projects/fdroid%2Ffdroiddata/merge_requests/49236/notes?sort=asc&per_page=50` — needs an authenticated session; unauthenticated `curl` gets 401, use a logged-in browser session or a GitLab token) rather than trusting the state described in an old copy of this file, then apply the change in `~/development/fdroiddata` (the working checkout, already on the right branch) and in the app repo's `fdroid/` copy, keeping both in sync per the header comment in `fdroid/dev.susiee.lilptero.yml`.

## Known gotcha: commit SHA drift after history rewrite

The app repo's git history was rewritten once to strip a personal email from commit metadata (2026-09-18), which changed every commit's SHA including the one `v0.1.2` pointed to. Any doc, comment, or old conversation summary written before that rewrite has a dead SHA. Always re-derive the live one with `git ls-remote --tags origin v0.1.2` rather than reusing a SHA quoted in prose — this file has been wrong about it twice already.

## Prompt for Claude

```text
Read fdroid/AI_HANDOFF.md, then verify the live MR state via the GitLab API (notes endpoint) rather than trusting this file's summary — it goes stale between sessions. Only act if there's new reviewer feedback to address or a new app version to sync into the MR. Do not cut a new release, open a replacement MR, or push to GitLab until you've confirmed the actual current state and, for anything public-facing, gotten explicit user approval.
```
