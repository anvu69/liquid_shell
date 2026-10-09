# liquid_shell_platform_interface

A common platform interface for the [`liquid_shell`][app] plugin.

It defines `LiquidShellPlatform`, the stream of `LiquidPlatformSignals`
(reduce transparency, battery saver, system blur disabled) that make
`liquid_shell` glass fall back to a solid fill, and the event-channel
implementation shared by the iOS and Android packages.

## Usage

Apps do not use this package directly. Depend on [`liquid_shell`][app].

To implement a new platform, extend `LiquidShellPlatform` and set
`LiquidShellPlatform.instance` from your package's `registerWith()`:

```dart
class LiquidShellMyOS extends LiquidShellPlatform {
  static void registerWith() {
    LiquidShellPlatform.instance = LiquidShellMyOS();
  }

  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(LiquidPlatformSignals.none);
}
```

## License

MIT. See [LICENSE](LICENSE).

[app]: https://pub.dev/packages/liquid_shell
