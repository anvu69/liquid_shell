import Foundation

/// What decides whether the native shell is installed (spec §5.1).
struct InstallFacts: Equatable {
  var isPad: Bool
  var osAtLeast26: Bool
  var isiOSAppOnMac: Bool
  var enabledInInfoPlist: Bool
  var disabledByEnvironment: Bool
  var registeredLate: Bool
  var rootIsFlutter: Bool
}

/// The install rule as a pure function. The first failing fact wins.
enum InstallPolicy {
  /// Info.plist opt-in key (Boolean).
  static let infoPlistKey = "LiquidShellNativeChrome"

  /// Diagnostic environment variable: `1` keeps the Flutter chrome.
  static let disableEnvironmentKey = "LIQUID_SHELL_NATIVE_OFF"

  /// nil: install. Otherwise why not.
  static func decide(_ facts: InstallFacts) -> NativeUnavailableReason? {
    if !facts.isPad { return .notIPad }
    if !facts.osAtLeast26 { return .osTooOld }
    if facts.isiOSAppOnMac { return .iPadAppOnMac }
    if !facts.enabledInInfoPlist { return .notEnabled }
    if facts.disabledByEnvironment { return .disabledByEnvironment }
    if facts.registeredLate { return .registeredLate }
    if !facts.rootIsFlutter { return .rootNotFlutter }
    return nil
  }
}
