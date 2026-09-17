# Submitting to F-Droid

Status: **recipe drafted and updated for the real v0.1.0 tag, not yet tested or submitted.** [dev.susiee.lilptero.yml](dev.susiee.lilptero.yml) in this folder is a working copy kept here for reference — it isn't live anywhere. F-Droid's actual metadata lives in a separate repo ([fdroiddata](https://gitlab.com/fdroid/fdroiddata)) that you submit a merge request against.

## Important: F-Droid re-signs the APK

F-Droid's build server compiles the app from source **on their own infrastructure** and signs the resulting APK with **F-Droid's own key**, not ours. That means:

- The APK from F-Droid and the APK from our [GitHub Releases](https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases) (signed with `android/keystore/release-key.jks`) are signed differently.
- A device can't have both installed as "the same app" — installing one over the other fails with a signature mismatch unless the first is uninstalled.
- This is normal and expected for most F-Droid apps. There's an opt-in "reproducible builds" path (F-Droid's `binary:` build type) where, if our GitHub release build is byte-for-byte reproducible from the tagged source, F-Droid can verify and publish *our* signed binary instead of re-signing — see [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds/). Worth pursuing later; not needed for the first submission.

## Why this app already qualifies on the easy criteria

- MIT licensed (F-Droid requires FOSS licensing) ✓
- No Google Play Services, Firebase, analytics, crash reporting, or ad SDKs — only `http` and `flutter_secure_storage` (Android Keystore, no proprietary backend) ✓
- `pubspec.lock` is committed, so dependency versions are pinned/reproducible ✓
- v0.1.0 is tagged and its GitHub Release build works, so `commit:` in the recipe points at a real, working commit (`88335637632149d32e23f846df1aa8062df36c20`) ✓

## The build recipe

F-Droid's build server builds Flutter apps by pulling the Flutter SDK in as a pinned `srclib` (not downloading a prebuilt tarball at build time — see the `srclibs: [flutter@3.47.4]` line in the draft recipe). The draft here is modeled on **[com.iakmds.librecamera.yml](https://gitlab.com/fdroid/fdroiddata/-/raw/master/metadata/com.iakmds.librecamera.yml)** — a real, currently-building Flutter app recipe fetched verbatim from fdroiddata, not paraphrased — so the `srclibs`/`build`/`output` shape is proven, not guessed. It's simpler than F-Droid's official template (which adds upstream-path/reproducible-build machinery LibreCamera's real recipe doesn't actually use for a basic submission).

## What I couldn't finish for you

Two things need to happen on your side specifically — I hit hard walls on both in this environment:

1. **Local test build.** `fdroidserver` isn't in the official Arch repos (AUR only), and installing anything here needs an interactive `sudo` password I don't have access to. Run this yourself:
   ```bash
   yay -S fdroidserver   # or paru -S fdroidserver
   ```
   Then, from a clone of your `fdroiddata` fork with this recipe copied in:
   ```bash
   fdroid build --verbose dev.susiee.lilptero:1
   ```
   This is the step most likely to need iteration — fix whatever it complains about before submitting.

2. **GitLab account.** Forking `fdroiddata` and opening a merge request needs a GitLab.com account tied to your own SSH key or login — I checked and this machine's SSH key isn't registered with GitLab (`git@gitlab.com` auth fails), and creating accounts on your behalf isn't something I do. Set one up yourself if you don't have one, add this machine's SSH key (`~/.ssh/id_ed25519.pub`) to it, then the fork/MR steps below will work the same way GitHub already does here.

## Step by step

1. ~~Cut a real release~~ — done, `v0.1.0` is tagged and its GitHub Release build succeeded.
2. ~~Fill in the recipe~~ — done, `dev.susiee.lilptero.yml` has the real `versionCode`/`versionName`/`commit`.
3. **Install `fdroidserver`** and test-build the recipe locally (see above). This is on you — see the blocker note.
4. **Create a GitLab account** if you don't have one, and add your SSH key to it (see above).
5. **Fork [fdroiddata](https://gitlab.com/fdroid/fdroiddata)**, add your tested recipe at `metadata/dev.susiee.lilptero.yml` (strip the comments first — F-Droid asks for that), and open a merge request.
6. **Wait for review.** Volunteer-run queue, days to weeks. Reviewers may ask for changes.
7. Once merged, the app appears in the official F-Droid repo within a build cycle or two.

Ping me once you've got a GitLab account and `fdroidserver` installed — I can pick the rest back up (drive `fdroid build`, iterate on the recipe based on its output, prep the fork/branch/commit for the MR) as long as you're driving the actual GitLab auth and the sudo-gated installs.

## Faster alternative: self-hosted repo

If you don't want to wait on the review queue, `fdroidserver` can also build and host your own personal F-Droid repo (a URL users add to the F-Droid client) without going through the official `fdroiddata` review — see [F-Droid's docs on running your own repository](https://f-droid.org/docs/Setup_an_F-Droid_App_Repo/). It publishes immediately but won't show up in the default F-Droid app's catalog until/unless the official submission above also lands.
