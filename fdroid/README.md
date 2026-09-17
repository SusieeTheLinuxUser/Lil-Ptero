# Submitting to F-Droid

Status: **not submitted yet.** [dev.susiee.lilptero.yml](dev.susiee.lilptero.yml) in this folder is a draft build recipe kept here for reference — it isn't live anywhere. F-Droid's actual metadata lives in a separate repo ([fdroiddata](https://gitlab.com/fdroid/fdroiddata)) that you submit a merge request against.

## Important: F-Droid re-signs the APK

F-Droid's build server compiles the app from source **on their own infrastructure** and signs the resulting APK with **F-Droid's own key**, not ours. That means:

- The APK from F-Droid and the APK from our [GitHub Releases](https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases) (signed with `android/keystore/release-key.jks`) are signed differently.
- A device can't have both installed as "the same app" — installing one over the other fails with a signature mismatch unless the first is uninstalled.
- This is normal and expected for most F-Droid apps. There's an opt-in "reproducible builds" path (F-Droid's `binary:` build type) where, if our GitHub release build is byte-for-byte reproducible from the tagged source, F-Droid can verify and publish *our* signed binary instead of re-signing — see [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds/). Worth pursuing later; not needed for the first submission.

## Why this app already qualifies on the easy criteria

- MIT licensed (F-Droid requires FOSS licensing) ✓
- No Google Play Services, Firebase, analytics, crash reporting, or ad SDKs — only `http` and `flutter_secure_storage` (Android Keystore, no proprietary backend) ✓
- `pubspec.lock` is committed, so dependency versions are pinned/reproducible ✓

## What's actually hard: the build recipe

F-Droid's build server builds Flutter apps by pulling the Flutter SDK in as a pinned `srclib` (not downloading a prebuilt tarball at build time — see the `srclibs: [flutter@3.47.4]` line in the draft recipe). This matches how real Flutter apps already on F-Droid do it (e.g. [Obtainium](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/dev.imranr.obtainium.fdroid.yml)), which the draft recipe here is modeled on, simplified since we ship one universal APK instead of Obtainium's per-ABI split builds.

**I haven't been able to test-build this recipe locally** — `fdroidserver` isn't installed on this machine and isn't in the official Arch repos (it's in the AUR). If you want to validate the recipe before submitting (strongly recommended — F-Droid's reviewers will bounce anything that doesn't build cleanly):

```bash
yay -S fdroidserver   # or paru -S fdroidserver
```

Then, from a clone of your `fdroiddata` fork with this recipe copied in:

```bash
fdroid build --verbose dev.susiee.lilptero:1
```

## Step by step

1. **Cut a real release first.** The recipe's `commit: v0.1.0` needs an actual git tag to exist — push one (`git tag v0.1.0 && git push --tags`) once you're happy with what's in `main`. This also triggers the GitHub Actions release workflow.
2. **Fill in the recipe.** Copy `fdroid/dev.susiee.lilptero.yml` and double check `versionCode`/`versionName`/`commit` match the real tag.
3. **Install `fdroidserver`** (see above) and test-build the recipe locally. Fix whatever it complains about — this is the step most likely to need iteration.
4. **Fork [fdroiddata](https://gitlab.com/fdroid/fdroiddata)** on GitLab, add your tested recipe at `metadata/dev.susiee.lilptero.yml`, and open a merge request.
5. **Wait for review.** This is a volunteer-run queue; it can take anywhere from days to weeks. Reviewers may ask for changes (versioning scheme, reproducibility, metadata fixes).
6. Once merged, the app appears in the official F-Droid repo within a build cycle or two.

## Faster alternative: self-hosted repo

If you don't want to wait on the review queue, `fdroidserver` can also build and host your own personal F-Droid repo (a URL users add to the F-Droid client) without going through the official `fdroiddata` review — see [F-Droid's docs on running your own repository](https://f-droid.org/docs/Setup_an_F-Droid_App_Repo/). It publishes immediately but won't show up in the default F-Droid app's catalog until/unless the official submission above also lands.
