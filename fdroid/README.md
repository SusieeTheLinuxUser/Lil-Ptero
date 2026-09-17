# Submitting to F-Droid

Status: **recipe is written, linted, and build-tested locally — it actually produces a working APK via `fdroid build`.** [dev.susiee.lilptero.yml](dev.susiee.lilptero.yml) in this folder is a working copy kept here for reference — it isn't live anywhere yet. F-Droid's actual metadata lives in a separate repo ([fdroiddata](https://gitlab.com/fdroid/fdroiddata)) that you submit a merge request against. Only one real blocker is left: a GitLab account (see below).

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
- `fastlane/metadata/android/en-US/` (title, short/full description, `changelogs/1.txt`) is in this repo — F-Droid's app store listing pulls from here, per the [official quick-start guide](https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/) ✓
- **The recipe actually builds.** `fdroid build --test dev.susiee.lilptero:1` ran the real F-Droid build pipeline — cloned the Flutter SDK as a pinned srclib, cloned our repo at the tagged commit, ran `flutter pub get` + `flutter build apk --release` inside F-Droid's own scanner/build machinery — and produced a working `app-release.apk`. Not just linted, actually built. ✓

## Two ways to submit — the direct merge request is the one F-Droid recommends

F-Droid's own [quick-start guide](https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/) is explicit that a **direct merge request** with your own tested metadata is "apparently the best way to get an app into the repository." Filing an issue against [fdroid/rfp](https://gitlab.com/fdroid/rfp) (their "Requests For Packaging" tracker) is the other option, but it's a lower-commitment "maybe a volunteer will package this" request — no guarantee anyone picks it up. Everything below is set up for the MR path; the RFP issue is just a cheap, non-blocking thing to also file while waiting.

## The build recipe

F-Droid's build server builds Flutter apps by pulling the Flutter SDK in as a pinned `srclib` (not downloading a prebuilt tarball at build time — see the `srclibs: [flutter@3.47.4]` line in the recipe). It's modeled on **[com.iakmds.librecamera.yml](https://gitlab.com/fdroid/fdroiddata/-/raw/master/metadata/com.iakmds.librecamera.yml)** — a real, currently-building Flutter app recipe fetched verbatim from fdroiddata — and confirmed against a real local build, not just guessed syntax. The `flutter` srclib definition itself (`srclibs/flutter.yml`, pointing at `github.com/flutter/flutter.git`) already exists in the real `fdroiddata` repo — you don't need to add it, only my local test harness (a minimal fake workspace, not a full `fdroiddata` clone) needed a copy of it.

## How the local build test was done (reproducible on your machine too)

`fdroidserver` doesn't need `sudo` at all — [F-Droid's own docs](https://f-droid.org/docs/Installing_the_Server_and_Repo_Tools/#fedoraarchlinux) recommend a plain Python venv install for Fedora/Arch:

```bash
git clone https://gitlab.com/fdroid/fdroidserver.git ~/development/fdroidserver
cd ~/development/fdroidserver
python3 -m venv env
source env/bin/activate
pip install -e .
```

Then, since testing one recipe doesn't need the *entire* `fdroiddata` repo (thousands of other apps' metadata), a minimal workspace works:

```bash
mkdir -p ~/development/fdroid-test-repo/{metadata,srclibs,config}
cd ~/development/fdroid-test-repo
# the recipe itself, comments stripped:
cp /path/to/Lil-Ptero/fdroid/dev.susiee.lilptero.yml metadata/
# F-Droid validates Categories/AntiFeatures against real config files:
curl -sf https://gitlab.com/fdroid/fdroiddata/-/raw/master/config/categories.yml -o config/categories.yml
curl -sf https://gitlab.com/fdroid/fdroiddata/-/raw/master/config/antiFeatures.yml -o config/antiFeatures.yml
# those configs reference icon files that must exist (content doesn't matter for testing):
grep -oP '(?<=icon: ).*' config/categories.yml config/antiFeatures.yml | cut -d: -f2 | sort -u | xargs -I{} touch config/{}
# the flutter srclib definition (already in real fdroiddata, just not in this fake workspace):
cat > srclibs/flutter.yml << 'EOF'
RepoType: git
Repo: https://github.com/flutter/flutter.git
EOF
```

```bash
source ~/development/fdroidserver/env/bin/activate
export ANDROID_HOME=~/Android/Sdk   # wherever your Android SDK is
fdroid lint dev.susiee.lilptero            # fast metadata check
fdroid build --test --no-tarball -v dev.susiee.lilptero:1   # the real build
```

First run will clone the full Flutter SDK repo (a few hundred MB, ~1 min) into `build/srclib/flutter` and our repo into `build/dev.susiee.lilptero` — both get reused on subsequent runs.

## What's left — GitLab account

The only remaining blocker is a GitLab.com account — forking `fdroiddata` and opening a merge request needs one tied to your own SSH key or login. I checked and this machine's SSH key isn't registered with GitLab (`git@gitlab.com` auth fails), and creating accounts on someone's behalf isn't something I do. Set one up yourself, add this machine's SSH key (`~/.ssh/id_ed25519.pub`) to it, and everything below works the same way GitHub already does here.

## Step by step

1. ~~Cut a real release~~ — done, `v0.1.0` is tagged and its GitHub Release build succeeded.
2. ~~Write and test the recipe~~ — done, linted *and* build-tested locally (see above).
3. ~~Add fastlane metadata~~ — done, `fastlane/metadata/android/en-US/`.
4. **Create a GitLab account** if you don't have one, and add this machine's SSH key (`~/.ssh/id_ed25519.pub`) to it.
5. **Fork [fdroiddata](https://gitlab.com/fdroid/fdroiddata)**, clone it, and make a branch named after the app ID (`dev.susiee.lilptero`).
6. Copy `fdroid/dev.susiee.lilptero.yml` into the fork as `metadata/dev.susiee.lilptero.yml`, with the comments stripped (F-Droid asks for that).
7. From inside that real `fdroiddata` clone, re-run `fdroid lint dev.susiee.lilptero` and `fdroid build --test dev.susiee.lilptero:1` once more — the real repo already has all the `config/`/`srclibs/` files my fake workspace needed recreated, so this should just work.
8. Commit as `New App: dev.susiee.lilptero` (their convention) and open a merge request against `fdroiddata`.
9. **Wait for review.** Volunteer-run queue, days to weeks. Reviewers may ask for changes.
10. Once merged, the app appears in the official F-Droid repo within a build cycle or two.

Optionally, also file the (much cheaper) [RFP issue](https://gitlab.com/fdroid/rfp/-/issues/new) in parallel — just needs the GitLab account from step 4, no SSH or local build. A ready-to-paste version is in [rfp-issue-draft.md](rfp-issue-draft.md) — before checking the "complies with the inclusion criteria" box, skim [f-droid.org/wiki/page/Inclusion_Policy](https://f-droid.org/wiki/page/Inclusion_Policy) yourself; it's your claim to F-Droid, not something to take on my word.

Ping me once you've got a GitLab account — I can pick the rest back up (fork, branch, commit, open the MR) since `fdroidserver` is already installed and the recipe is already proven to build.

## Faster alternative: self-hosted repo

If you don't want to wait on the review queue, `fdroidserver` can also build and host your own personal F-Droid repo (a URL users add to the F-Droid client) without going through the official `fdroiddata` review — see [F-Droid's docs on running your own repository](https://f-droid.org/docs/Setup_an_F-Droid_App_Repo/). It publishes immediately but won't show up in the default F-Droid app's catalog until/unless the official submission above also lands.
