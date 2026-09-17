# F-Droid reviewer handoff

Use this file for the current F-Droid task instead of rereading the full project documentation.

## Current state

- App: `dev.susiee.lilptero`, release `v0.1.2`, build number `3`.
- F-Droid MR: [!49236](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/49236), branch `dev.susiee.lilptero` in the `SusieeTheLinuxUser/fdroiddata` fork.
- Reviewer `linsui` requested the Flutter template, per-ABI builds, and reproducible-build metadata.
- The ABI work is already released: versionCodes `31`, `32`, and `33` for `armeabi-v7a`, `arm64-v8a`, and `x86_64`.
- The app-repo recipe contains the reproducibility fix, but it is not committed, copied to `~/development/fdroiddata`, pushed, or posted to the MR yet.

## Reproducibility result

The first comparison failed because build paths differed. Only two APK entries changed:

- `libapp.so` embedded `.dart_tool/flutter_build/dart_plugin_registrant.dart` with the absolute checkout path.
- `libdartjni.so` differed only in its 20-byte GNU build ID, caused by the Android SDK and Pub-cache paths used by the native `jni` package.

The recipe now:

1. Builds at GitHub's path: `/home/runner/work/Lil-Ptero/Lil-Ptero`.
2. Downloads dependencies into a project-local `.pub-cache` so F-Droid scans them.
3. Maps `$$SDK$$` to GitHub's `/usr/local/lib/android/sdk` while compiling `jni`.
4. Moves the already-scanned cache to `/home/runner/.pub-cache` for compilation.
5. Uses one `binary:` URL per ABI and the signing certificate fingerprint:
   `940bcf557d80048ecd1bc7f2dd02de8f0d4591592b9922ee8f1af299754d56a6`.

All three rebuilt APKs became byte-for-byte identical to the published GitHub APK after copying the upstream signature. `apksigner verify`, `fdroid lint`, `flutter analyze`, and all 22 Flutter tests passed.

Published APK SHA-256 values:

- ARMv7: `26f53aef5adf1be4abb3af58fdea77ba9a968aac5102ca1ef5df5d9e0b68f51b`
- ARM64: `b3bb0264257b404ed5bc371d9013348210ed64d495bcfc9497f139bd9e75a842`
- x86_64: `12dfa40fc479f3b58951cdc83f87408bd50e7d21d6c0526f783b64cd82e00e92`

## Next actions

1. Review and commit `fdroid/dev.susiee.lilptero.yml` in the app worktree.
2. Copy it to `~/development/fdroiddata/metadata/dev.susiee.lilptero.yml` and run `fdroid rewritemeta dev.susiee.lilptero` if required by fdroiddata formatting.
3. Run the real buildserver/pipeline validation. Local `fdroid build` skips recipe `sudo:` commands, so the final fixed-path recipe cannot be fully exercised in ordinary local mode.
4. Commit and push the fdroiddata branch, then reply to `linsui` with the ABI and reproducibility evidence.
5. Do not create another release: the existing v0.1.2 APKs are reproducible.

## Prompt for Claude

```text
Read fdroid/AI_HANDOFF.md, then inspect the current diff in the claude/fdroid-abi-split-review worktree. Continue only the F-Droid MR !49236 reviewer-response task. Verify the recipe is synchronized with the handoff, preserve the three ABI versionCodes and reproducible-build fields, and report the exact remaining commands/actions. Do not cut a new release, change app code, push, or post to GitLab until I explicitly approve those external actions. Keep the response concise and evidence-based.
```
