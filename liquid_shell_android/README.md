# liquid_shell_android

The Android implementation of [`liquid_shell`][app].

It reports reduce transparency (animator duration scale 0 or high contrast), battery saver (`PowerManager.isPowerSaveMode`) and system blur disabled (`WindowManager.isCrossWindowBlurEnabled`, API 31+). No permissions.

## Usage

This package is [endorsed][endorsed]: depend on `liquid_shell` and it is
added to your app automatically. You never import it.

## License

MIT. See [LICENSE](LICENSE).

[app]: https://pub.dev/packages/liquid_shell
[endorsed]: https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin
