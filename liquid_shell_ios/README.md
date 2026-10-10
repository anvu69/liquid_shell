# liquid_shell_ios

The iOS implementation of [`liquid_shell`][app].

It reports Reduce Transparency (`UIAccessibility.isReduceTransparencyEnabled`). iOS 15.0 or later.

On iOS 26 and later, in an app that opts in, it also installs the native
`UITabBarController` chrome on every iPhone and iPad (the floating tab bar
at compact width, the top bar and sidebar at regular width), and reads the
iPadOS window controls. See `liquid_shell`'s
[native chrome guide](https://github.com/anvu69/liquid_shell/blob/main/liquid_shell/doc/native_chrome.md).

CocoaPods is the tested path; a Swift Package manifest is included but unverified until Flutter's SwiftPM build works on Xcode 27.

## Usage

This package is [endorsed][endorsed]: depend on `liquid_shell` and it is
added to your app automatically. You never import it.

## License

MIT. See [LICENSE](LICENSE).

[app]: https://pub.dev/packages/liquid_shell
[endorsed]: https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin
