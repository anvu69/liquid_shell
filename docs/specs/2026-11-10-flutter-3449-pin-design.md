# Pin Flutter 3.44.9 locally: the simulator build works on Xcode 27.1 (VK-931)

Status: approved by the owner on 2026-11-10 (decisions 1–2: "ok hết").

## 1. Problem

On Xcode 27.1 (27A9275), `fvm flutter build ios --simulator --debug` fails in
`liquid_shell/example`:

```
Flutter.framework … does not contain architectures arm64 x86_64
```

The framework's simulator slice does contain `x86_64 arm64`. The error comes from
Flutter 3.44.6's `thinFramework` in `flutter_tools/lib/src/build_system/targets/darwin.dart`.
It calls `lipo -verify_arch arm64 x86_64` once, with both architectures. The `lipo` in
Xcode 27 rejects that call ("requires exactly one input file"), and the tool then
reports the architectures as missing.

`make ios-unit` is not affected, because it runs `flutter build ios --config-only` and
then `xcodebuild build-for-testing`, and neither runs that step. Every
`flutter build ios --simulator` and `flutter drive` on a simulator is affected, for
example `tool/integration_ios_native.sh`.

The Flutter stable CHANGELOG lists the fix in 3.44.8: "flutter/188346 When building on
macOS or iOS using the Xcode 27 toolchain, the build will fail due to a lipo
verification error" (fix PR flutter/flutter#188625). CI is not affected, because it
installs `flutter-version: 3.44.x`, which is the latest patch, 3.44.9. Only the local
pin in `.fvmrc` (3.44.6) is behind.

Evidence: `.superpowers/sdd/vk931-investigation.md`.

## 2. Decision

Raise `.fvmrc` to **3.44.9**, the patch CI already runs. That puts the local toolchain,
the pre-commit hook and the golden reference on one version.

Rejected: keep 3.44.6 and export `FLUTTER_XCODE_ARCHS=arm64` in the simulator scripts.
It works, but it is a workaround that has to be removed later, and the local
toolchain would still differ from CI.

## 3. What changes

- `.fvmrc`: `3.44.6` → `3.44.9`.
- The docs that name the pin: `CONTRIBUTING.md` (toolchain section), the comment at
  the top of the `Makefile`, and the goldens line in `CLAUDE.md`. They now name 3.44.9.
  The SDK floor stays `>=3.44.0` in every pubspec: the floor and the local pin are
  different things, and the docs say so.
- Plan and spec history files are not edited.

## 4. Verification

1. Before the change, on 3.44.6: `fvm flutter build ios --simulator --debug` in
   `liquid_shell/example` fails with the lipo error.
2. After the change, on 3.44.9: the same command succeeds.
3. `.githooks/pre-commit` exits 0 on 3.44.9. It runs format, analyze and every Dart
   test, the goldens included.
4. `make ios-unit` on a freshly created iPhone Duo (iOS 27.1) simulator: exit 0,
   0 failed.
