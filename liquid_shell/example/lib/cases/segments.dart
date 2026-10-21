import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/chrome_mode.dart';
import 'package:liquid_shell_example/support/drawn_by_flutter.dart';

/// One control of the segments case and of the native reference screen
/// (`ios/Runner/SegmentReferenceViewController.swift`).
typedef SegmentsRow = ({
  String id,
  List<String> labels,
  bool fullWidth,
  bool enabled,
  double trackTop,
});

/// The controls, top to bottom (spec VK-550 §13). The native reference
/// screen puts each 32 pt `UISegmentedControl`'s top at `trackTop`, in
/// points from the top of the screen: full width between 16 pt margins,
/// or centred at its intrinsic width. Here the 32 pt track sits on the same
/// line, in the middle of the control's 44 pt box.
const kSegmentsRows = <SegmentsRow>[
  (
    id: 'intrinsic3',
    labels: ['All', 'Songs', 'Places'],
    fullWidth: false,
    enabled: true,
    trackTop: 160,
  ),
  (
    id: 'full3',
    labels: ['All', 'Songs', 'Places'],
    fullWidth: true,
    enabled: true,
    trackTop: 240,
  ),
  (
    id: 'full2',
    labels: ['Songs', 'Places'],
    fullWidth: true,
    enabled: true,
    trackTop: 320,
  ),
  (
    id: 'full5',
    labels: ['One', 'Two', 'Three', 'Four', 'Five'],
    fullWidth: true,
    enabled: true,
    trackTop: 400,
  ),
  (
    id: 'disabled3',
    labels: ['All', 'Songs', 'Places'],
    fullWidth: true,
    enabled: false,
    trackTop: 480,
  ),
];

/// The right-to-left switch.
const kSegmentsRtlKey = ValueKey<String>('segments-rtl');

/// The text ×2 switch.
const kSegmentsLargeTextKey = ValueKey<String>('segments-large-text');

/// "Next segment": the app changes the full-width three-segment control's
/// selection.
const kSegmentsNextKey = ValueKey<String>('segments-next');

/// The full-width three-segment control: the README's snippet, the one
/// "Next segment" moves and the acceptance traces drive.
const _scopesId = 'full3';

/// Side margins of the full-width controls, as the reference screen's
/// layout margins.
const _margin = 16.0;

/// The native control's height: its track's centre is half of it below
/// `trackTop`.
const _nativeHeight = 32.0;

/// Each control is centred in a band this tall (the rows' pitch).
const _band = 80.0;

/// Where the panel under the controls starts.
const _panelTop = 536.0;

/// `LiquidSegmentedControl` over the stripes of the native reference
/// screen, at its frames (spec VK-550 §13, §14.5): tool/segment_frames.sh
/// records both and lays them side by side. Two, three and five segments
/// at full width, one sized to its labels, one disabled; switches for
/// right to left and text ×2, and a selection made from code.
class SegmentsCase extends StatefulWidget {
  /// Creates the case.
  const SegmentsCase({super.key});

  @override
  State<SegmentsCase> createState() => _SegmentsCaseState();
}

class _SegmentsCaseState extends State<SegmentsCase> {
  // #docregion segments
  int _scope = 0;

  Widget _scopes() => LiquidSegmentedControl(
    segments: const [
      LiquidSegment(label: 'All'),
      LiquidSegment(label: 'Songs'),
      LiquidSegment(label: 'Places'),
    ],
    selectedIndex: _scope,
    // Controlled: rebuild with the index the user chose.
    onChanged: (i) => setState(() => _scope = i),
  );
  // #enddocregion segments

  /// The other controls' indices, as the native screen starts: the first.
  final Map<String, int> _selected = {
    for (final row in kSegmentsRows)
      if (row.id != _scopesId) row.id: 0,
  };
  bool _rtl = false;
  bool _largeText = false;

  /// The control of [row]: [_scopes], or one built from the row. A null
  /// `onChanged` disables a control; `expand: false` sizes every segment
  /// to the widest label.
  Widget _control(SegmentsRow row) => row.id == _scopesId
      ? _scopes()
      : LiquidSegmentedControl(
          segments: [
            for (final label in row.labels) LiquidSegment(label: label),
          ],
          selectedIndex: _selected[row.id],
          onChanged: row.enabled
              ? (i) => setState(() => _selected[row.id] = i)
              : null,
          expand: row.fullWidth,
        );

  /// The app's own change: the lens slides, and `onChanged` is not called.
  void _next() => setState(() => _scope = (_scope + 1) % 3);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget controls = Stack(
      children: [
        for (final row in kSegmentsRows)
          Positioned(
            left: _margin,
            right: _margin,
            top: row.trackTop + _nativeHeight / 2 - _band / 2,
            height: _band,
            child: Center(
              child: KeyedSubtree(
                key: ValueKey('segments-${row.id}'),
                child: _control(row),
              ),
            ),
          ),
      ],
    );
    controls = Directionality(
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      child: controls,
    );
    if (_largeText) {
      controls = MediaQuery(
        data: media.copyWith(textScaler: const TextScaler.linear(2)),
        child: controls,
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: SegmentsStripesPainter(dark: dark)),
          ),
          Positioned.fill(child: controls),
          Positioned(
            top: media.padding.top,
            left: 4,
            right: _margin,
            child: _TitleRow(dark: dark),
          ),
          Positioned(
            top: _panelTop,
            left: _margin,
            right: _margin,
            bottom: 0,
            child: _panel(context, media),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, MediaQueryData media) {
    final mode = ChromeModeScope.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.only(bottom: media.padding.bottom + 8),
      children: [
        // Its own Material: the list tiles' ink shows on it.
        Material(
          color: scheme.surface.withValues(alpha: 0.94),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DrawnByFlutterNote(),
                if (mode != null) ChromeModeSwitch(mode: mode),
                SwitchListTile(
                  key: kSegmentsRtlKey,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Right to left'),
                  value: _rtl,
                  onChanged: (on) => setState(() => _rtl = on),
                ),
                SwitchListTile(
                  key: kSegmentsLargeTextKey,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Text ×2'),
                  value: _largeText,
                  onChanged: (on) => setState(() => _largeText = on),
                ),
                TextButton(
                  key: kSegmentsNextKey,
                  onPressed: _next,
                  child: const Text('Next segment, from code'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The page title, with a back button when there is a page to go back to.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        if (navigator.canPop()) BackButton(onPressed: navigator.maybePop),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Text(
              'Segmented control',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                // Over the stripes and the system background.
                color: dark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The reference screen's stripes:
/// bands 20 pt tall every 40 pt, falling 45° to the right, over the system
/// background, in iOS 26's eight system colours (`.systemRed` …
/// `.systemPink`), light or [dark].
class SegmentsStripesPainter extends CustomPainter {
  /// Creates the painter.
  const SegmentsStripesPainter({required this.dark});

  /// Dark appearance: black background, the dark system colours.
  final bool dark;

  /// Red, orange, yellow, green, teal, blue, purple, pink (iOS 26).
  static const _light = [
    Color(0xFFFF383C),
    Color(0xFFFF8D28),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C3D0),
    Color(0xFF0088FF),
    Color(0xFFCB30E0),
    Color(0xFFFF2D55),
  ];

  /// The same, dark.
  static const _dark = [
    Color(0xFFFF4245),
    Color(0xFFFF9230),
    Color(0xFFFFD600),
    Color(0xFF30D158),
    Color(0xFF00D2E0),
    Color(0xFF0091FF),
    Color(0xFFDB34F2),
    Color(0xFFFF375F),
  ];

  /// The stripes' vertical period; each band is half of it.
  static const double _pitch = 40;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? Colors.black : Colors.white,
    );
    final colours = dark ? _dark : _light;
    final w = size.width;
    // Band i starts at (0, 40 i) and falls to (w, 40 i + w); the first
    // ones start above the screen.
    for (
      var i = (-w / _pitch).floor();
      i * _pitch < size.height + _pitch;
      i++
    ) {
      final y = i * _pitch;
      final band = Path()
        ..moveTo(0, y)
        ..lineTo(w, y + w)
        ..lineTo(w, y + w + _pitch / 2)
        ..lineTo(0, y + _pitch / 2)
        ..close();
      canvas.drawPath(band, Paint()..color = colours[i % colours.length]);
    }
  }

  @override
  bool shouldRepaint(SegmentsStripesPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
