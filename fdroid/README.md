# Submitting to F-Droid

Status: **all reviewer feedback addressed and pushed — waiting on F-Droid, not on us.** [Merge request !49236](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/49236) is open against `fdroiddata`, from `gitlab.com/SusieeTheLinuxUser/fdroiddata` branch `dev.susiee.lilptero` (head `d1d7e706`). Reviewer `linsui` went through three rounds — Flutter template + ABI split, then reproducible-build metadata, then pinning the Flutter version and a version-agnostic JNI patch path — and on 2026-09-18 called the MR "mostly ready," to be tested when they get to it; fdroiddata has a large review backlog. **No action needed unless a new app version ships**, in which case update this MR rather than opening a new one. For a compact agent handoff, read [AI_HANDOFF.md](AI_HANDOFF.md).

## CI feedback so far

**v0.1.0 (versionCode 1) — rejected by CI.** The `check apk` job failed: `ERROR Found extra signing block 'Dependency metadata'`. Android Gradle Plugin embeds a dependency-metadata block in the APK signing block by default, for Play Console's dependency-vulnerability scanning — irrelevant since we don't publish there, and F-Droid's scanner treats any extra signing-block content as suspicious and rejects the build outright. `fdroid build` itself had succeeded; this was a separate, stricter scanning job, so don't assume a green `fdroid build` means CI will pass.

**Fix**: added `dependenciesInfo { includeInApk = false; includeInBundle = false }` to `android/app/build.gradle.kts`. Cut v0.1.1 (versionCode 2) with the fix, updated the recipe to point at it, and verified locally with `fdroid scanner <apk> --exit-code` (not just `fdroid build`) before pushing — exit code 0, no problems found. The replacement pipeline later passed.

**Confirmed fixed**: pipeline `2858758122` (commit `bc9f90fb`) finished on 2026-09-17 — every job passed, including `check apk`. The `dependenciesInfo` fix works; no further recipe changes needed for this rejection. Re-check any future pipeline the same way:
```bash
curl -s "https://gitlab.com/api/v4/projects/SusieeTheLinuxUser%2Ffdroiddata/pipelines/<id>" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])"
curl -s "https://gitlab.com/api/v4/projects/SusieeTheLinuxUser%2Ffdroiddata/pipelines/<id>/jobs" | python3 -c "
import json,sys
for j in json.load(sys.stdin): print(j['name'], j['status'])"
```
The GitHub Releases build for v0.1.1 also finished successfully — the signed APK is published at [github.com/SusieeTheLinuxUser/Lil-Ptero/releases](https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases). Job-level GitLab logs (not just status) need browser auth — the public API works for status/job-lists but not job traces; ask the user to paste log output if a job fails and the reason isn't obvious from status alone.

### Human review: ABI splits and reproducible builds

Reviewer `linsui` asked for three changes after the green v0.1.1 pipeline:

1. Follow `templates/build-flutter.yml`.
2. Publish one build per ABI with versionCodes derived as `base * 10 + ABI digit`.
3. Add `binary:` URLs and `AllowedAPKSigningKeys` so F-Droid can verify the upstream-signed release.

The ABI change shipped in `v0.1.2` (`0.1.2+3`): ARMv7 is versionCode `31`, ARM64 is `32`, and x86_64 is `33`. The release workflow publishes all three split APKs, and the recipe has one `Builds` block per ABI.

The first reproducibility test failed with `APK integrity check failed. CHUNKED_SHA256 digest mismatch`. The APKs had identical sizes and ZIP layouts, but two native libraries differed:

- `libapp.so` embedded the absolute path to `.dart_tool/flutter_build/dart_plugin_registrant.dart`. GitHub used `/home/runner/work/Lil-Ptero/Lil-Ptero`; the local F-Droid build used its checkout path.
- `libdartjni.so` differed only in its 20-byte GNU build ID. The `jni` package's native build included the Android SDK and Pub-cache paths in the inputs used to calculate that ID.

The working recipe mirrors GitHub's checkout path, downloads packages into a local `.pub-cache` for scanning, adds `-ffile-prefix-map=$$SDK$$=/usr/local/lib/android/sdk` to `jni`'s CMake build, and moves the already-scanned cache to `/home/runner/.pub-cache` only for compilation. This is enough to reproduce the existing v0.1.2 binaries; no new release is required.

Verification results:

- `fdroid lint`: clean.
- ARMv7, ARM64, and x86_64: the rebuilt unsigned payload accepts the published APK's copied signature.
- The resulting APKs are byte-for-byte identical to the GitHub Release files.
- `apksigner verify`: passes for all three.
- `flutter analyze`: clean; `flutter test`: all 22 tests pass.

Published APK SHA-256 values:

- ARMv7: `26f53aef5adf1be4abb3af58fdea77ba9a968aac5102ca1ef5df5d9e0b68f51b`
- ARM64: `b3bb0264257b404ed5bc371d9013348210ed64d495bcfc9497f139bd9e75a842`
- x86_64: `12dfa40fc479f3b58951cdc83f87408bd50e7d21d6c0526f783b64cd82e00e92`

Local `fdroid build` skips recipe `sudo:` commands unless it is running on a dedicated buildserver. Therefore the final end-to-end confirmation must come from a buildserver or the MR pipeline; the equivalent path-normalized builds above already prove the payload itself is reproducible.

## Signing behavior

For an ordinary source-only recipe, F-Droid compiles the app and signs it with F-Droid's key. That means:

- The APK from F-Droid and the APK from our [GitHub Releases](https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases) (signed with `android/keystore/release-key.jks`) are signed differently.
- A device can't have both installed as "the same app" — installing one over the other fails with a signature mismatch unless the first is uninstalled.
- This is normal for most F-Droid apps.

This submission now uses F-Droid's reproducible-build `binary:` path. F-Droid independently rebuilds each APK, copies the signature from the corresponding GitHub Release APK, and accepts it only if signature verification succeeds. `AllowedAPKSigningKeys` pins the expected release certificate. If the recipe is accepted, users should receive the upstream-signed reproducible APK rather than a differently signed F-Droid build. See [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds/).

## Why this app already qualifies on the easy criteria

- MIT licensed (F-Droid requires FOSS licensing) ✓
- No Google Play Services, Firebase, analytics, crash reporting, or ad SDKs — only `http` and `flutter_secure_storage` (Android Keystore, no proprietary backend) ✓
- `pubspec.lock` is committed, so dependency versions are pinned/reproducible ✓
- v0.1.2 is tagged and its three GitHub Release APKs work, so each recipe block points at real commit `9ce3dd68ca951a26017248fb97c4ba52160baf98` (tag `v0.1.2` — the app repo's history was later rewritten to strip a personal email from commits, which orphaned the original SHA quoted here in earlier revisions; always re-verify with `git ls-remote --tags origin v0.1.2` rather than trusting a hash in prose) ✓
- `fastlane/metadata/android/en-US/` (title, short/full description, per-version changelogs) is in this repo — F-Droid's app store listing pulls from here, per the [official quick-start guide](https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/) ✓
- The previous source recipe built and passed the scanner. The current reproducible recipe is lint-clean and all three path-normalized payloads match their published binaries; the final buildserver/pipeline run is still pending because ordinary local mode skips `sudo:` setup. ✓

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
fdroid lint dev.susiee.lilptero                              # fast metadata check
fdroid build --test --no-tarball -v dev.susiee.lilptero:31
fdroid build --test --no-tarball -v dev.susiee.lilptero:32
fdroid build --test --no-tarball -v dev.susiee.lilptero:33
fdroid scanner --verbose --exit-code tmp/dev.susiee.lilptero_31.apk
fdroid scanner --verbose --exit-code tmp/dev.susiee.lilptero_32.apk
fdroid scanner --verbose --exit-code tmp/dev.susiee.lilptero_33.apk
```

(Update the version codes above when the base build number changes.)

First run will clone the full Flutter SDK repo (a few hundred MB, ~1 min) into `build/srclib/flutter` and our repo into `build/dev.susiee.lilptero` — both get reused on subsequent runs. **Run the `fdroid scanner` step too, not just `fdroid build`** — v0.1.0 passed `fdroid build` cleanly and still got rejected by CI's separate scanner check (see "CI feedback so far" above).

Do not pipe a long-running build directly to `tail -40` when you need live progress: `tail -40` buffers until the producer exits. F-Droid may also launch Meld for a failed binary comparison; while Meld is open, `fdroid build` is intentionally waiting for that GUI process to close rather than compiling.

The current recipe's fixed GitHub checkout path is created by `sudo:`. Ordinary local mode explicitly skips those commands, so use a dedicated F-Droid buildserver/VM for the final recipe test. A local manual reproduction is still useful for diagnosing binary differences, but it is not a substitute for the buildserver or MR pipeline.

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
7. ~~First CI pipeline~~ — failed on `check apk` (v0.1.0's "Dependency metadata" signing block); fixed in v0.1.1. Pipeline `2858758122` passed.
8. ~~Prepare reviewer-requested ABI splits~~ — released as v0.1.2 with versionCodes 31/32/33.
9. ~~Diagnose and fix reproducibility~~ — the app-repo recipe now reproduces all three existing v0.1.2 APKs.
10. ~~Commit, copy to fdroiddata, run the pipeline, push, reply to `linsui`~~ — done 2026-09-18.
11. ~~Second reviewer round: pin Flutter version, fix JNI sed path~~ — done same day; full pipeline (`fdroid build`, `check apk`, `fdroid lint`, `fdroid rewritemeta`) passed: https://gitlab.com/SusieeTheLinuxUser/fdroiddata/-/pipelines/2862036916
12. `linsui` replied: MR is "mostly ready," will be tested against F-Droid's queue. **Nothing to do until either they respond again or a new app version ships.**
13. Once merged, the app appears in the official F-Droid repo within a build cycle or two.

The RFP issue ([rfp-issue-draft.md](rfp-issue-draft.md)) was not filed — the direct MR was opened instead, per F-Droid's own recommendation (see above). If a future agent is asked to file it anyway, skim [f-droid.org/wiki/page/Inclusion_Policy](https://f-droid.org/wiki/page/Inclusion_Policy) before checking the "complies with the inclusion criteria" box — that's a claim made to F-Droid, not something to check on a memory of this file alone.

## Faster alternative: self-hosted repo

If you don't want to wait on the review queue, `fdroidserver` can also build and host your own personal F-Droid repo (a URL users add to the F-Droid client) without going through the official `fdroiddata` review — see [F-Droid's docs on running your own repository](https://f-droid.org/docs/Setup_an_F-Droid_App_Repo/). It publishes immediately but won't show up in the default F-Droid app's catalog until/unless the official submission above also lands.
