import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_android/liquid_shell_android.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  test('registerWith installs the event-channel implementation', () {
    LiquidShellAndroid.registerWith();
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });
}
