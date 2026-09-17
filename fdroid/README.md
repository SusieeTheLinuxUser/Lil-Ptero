# Submitting to F-Droid

Status: **submitted.** [Merge request !49236](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/49236) is open against `fdroiddata`, from a fork at `gitlab.com/SusieeTheLinuxUser/fdroiddata` (branch `dev.susiee.lilptero`). [dev.susiee.lilptero.yml](dev.susiee.lilptero.yml) in this folder is kept in sync with `metadata/dev.susiee.lilptero.yml` in that fork — edit it here first, re-test (see below), then apply the same change there and push to the `dev.susiee.lilptero` branch to update the MR. Now waiting on F-Droid's CI and volunteer review.

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

## Current state and local setup

Everything needed to get here is already set up on this machine (and reproducible on any other via the commands above):

- GitLab account created, this machine's SSH key added to it, `git@gitlab.com` auth confirmed working.
- Fork exists at `gitlab.com/SusieeTheLinuxUser/fdroiddata`, cloned locally at `~/development/fdroiddata` (shallow clone, `master` branch only — this repo has ~9,200 metadata files, don't do a full clone).
- `fdroidserver` installed at `~/development/fdroidserver` via the sudo-free venv method (see below) — activate with `source ~/development/fdroidserver/env/bin/activate` before running any `fdroid` command.
- Work happens on the `dev.susiee.lilptero` branch in that fork clone. It's already pushed and the MR (!49236) is open against it — new commits pushed to that branch update the MR automatically, no need to open a new one.

## Step by step (already done once — for reference / redoing after CI feedback)

1. ~~Cut a real release~~ — done, `v0.1.0` is tagged and its GitHub Release build succeeded.
2. ~~Write and test the recipe~~ — done, linted *and* build-tested locally (see above).
3. ~~Add fastlane metadata~~ — done, `fastlane/metadata/android/en-US/`.
4. ~~Create a GitLab account~~, add SSH key, ~~fork `fdroiddata`~~ — all done.
5. ~~Clone the fork, branch `dev.susiee.lilptero`, copy the recipe in (comments stripped via `fdroid rewritemeta`), commit as `New App: dev.susiee.lilptero`, push~~ — done.
6. ~~Open the merge request~~ — done, [!49236](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/49236), using their "App inclusion" MR template.
7. **Waiting on F-Droid's CI pipeline and volunteer review.** Volunteer-run queue, days to weeks. Reviewers may ask for changes — if so, edit the recipe in *this* repo, re-test locally (see above), copy the change into `~/development/fdroiddata/metadata/dev.susiee.lilptero.yml`, commit, and push to the `dev.susiee.lilptero` branch — that updates the existing MR.
8. Once merged, the app appears in the official F-Droid repo within a build cycle or two.

The RFP issue ([rfp-issue-draft.md](rfp-issue-draft.md)) was not filed — the direct MR was opened instead, per F-Droid's own recommendation (see above). If a future agent is asked to file it anyway, skim [f-droid.org/wiki/page/Inclusion_Policy](https://f-droid.org/wiki/page/Inclusion_Policy) before checking the "complies with the inclusion criteria" box — that's a claim made to F-Droid, not something to check on a memory of this file alone.

## Faster alternative: self-hosted repo

If you don't want to wait on the review queue, `fdroidserver` can also build and host your own personal F-Droid repo (a URL users add to the F-Droid client) without going through the official `fdroiddata` review — see [F-Droid's docs on running your own repository](https://f-droid.org/docs/Setup_an_F-Droid_App_Repo/). It publishes immediately but won't show up in the default F-Droid app's catalog until/unless the official submission above also lands.
