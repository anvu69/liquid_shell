import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  test('registerWith installs the event-channel implementation', () {
    LiquidShellIOS.registerWith();
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });
}
