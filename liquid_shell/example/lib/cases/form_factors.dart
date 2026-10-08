import 'package:flutter/material.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';

/// A device frame: logical size and safe-area padding.
typedef DeviceFrame = ({String name, Size size, EdgeInsets padding});

/// The reference frames of the goldens.
const kDeviceFrames = <DeviceFrame>[
  (
    name: 'iPhone',
    size: Size(393, 852),
    padding: EdgeInsets.only(top: 59, bottom: 34),
  ),
  (
    name: 'iPad portrait',
    size: Size(834, 1194),
    padding: EdgeInsets.only(top: 24, bottom: 20),
  ),
  (
    name: 'iPad landscape',
    size: Size(1194, 834),
    padding: EdgeInsets.only(top: 24, bottom: 20),
  ),
  (
    name: 'Android',
    size: Size(412, 915),
    padding: EdgeInsets.only(top: 24, bottom: 24),
  ),
];

/// The basic shell inside fixed device frames, scaled to fit, so one
/// screen shows every layout.
class FormFactorsCase extends StatelessWidget {
  /// Creates the case.
  const FormFactorsCase({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Form factors')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final frame in kDeviceFrames) ...[
          Text(frame.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // #docregion readme
          AspectRatio(
            aspectRatio: frame.size.aspectRatio,
            child: FittedBox(
              child: SizedBox.fromSize(
                size: frame.size,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: frame.size,
                    padding: frame.padding,
                    viewPadding: frame.padding,
                  ),
                  child: const BasicTabsCase(),
                ),
              ),
            ),
          ),
          // #enddocregion readme
          const SizedBox(height: 24),
        ],
      ],
    ),
  );
}
