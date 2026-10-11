import 'package:flutter/services.dart';

/// Answered by the example's iOS Runner (`AppDelegate.swift`).
const launchDemoChannel = MethodChannel('liquid_shell_example/launch');

/// The demo the example was launched with (`LIQUID_SHELL_EXAMPLE_DEMO`,
/// set by the UI tests, spec P3a §9.4), or null.
///
/// Dart's `Platform.environment` is empty on iOS, so the Runner reads the
/// process environment and answers over [launchDemoChannel]. Elsewhere
/// nothing answers: no demo.
Future<String?> launchDemo() async {
  try {
    return await launchDemoChannel.invokeMethod<String>('demo');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
