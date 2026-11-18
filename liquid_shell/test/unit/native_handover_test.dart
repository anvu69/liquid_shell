import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/native/native_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

// The phase table of the page bar hand-over (spec 2026-11-18 applied-epoch
// §2.3). `layout`: this frame draws native's layout.

NativeHandoverStep _step(
  NativeHandover phase, {
  bool engaged = true,
  bool releasable = true,
  bool mine = false,
  bool nativeUp = false,
  bool barMismatch = false,
  bool released = false,
  bool timedOut = false,
  bool moved = false,
  bool resized = false,
  bool flutterBar = true,
}) => nativeHandoverStep(
  phase,
  engaged: engaged,
  releasable: releasable,
  mine: mine,
  nativeUp: nativeUp,
  barMismatch: barMismatch,
  released: released,
  timedOut: timedOut,
  moved: moved,
  resized: resized,
  flutterBar: flutterBar,
);

void expectStep(
  NativeHandoverStep step,
  NativeHandover phase, {
  required bool layout,
  bool restart = false,
}) {
  expect(step.phase, phase);
  expect(step.layout, layout, reason: 'layout');
  expect(step.restart, restart, reason: 'restart');
}

void main() {
  group('an engage', () {
    test('native not up: waiting, the Flutter bar', () {
      expectStep(
        _step(NativeHandover.none),
        NativeHandover.waiting,
        layout: false,
        restart: true,
      );
    });

    test('my config already shown (a reconnect): done at once', () {
      expectStep(
        _step(NativeHandover.none, mine: true, nativeUp: true),
        NativeHandover.done,
        layout: true,
      );
    });

    test("another config up: takeover, native's layout", () {
      expectStep(
        _step(NativeHandover.none, nativeUp: true),
        NativeHandover.takeover,
        layout: true,
        restart: true,
      );
    });

    test('another config up without a page bar: still a takeover (the '
        'page bar alone differs)', () {
      expectStep(
        _step(NativeHandover.none, nativeUp: true, barMismatch: true),
        NativeHandover.takeover,
        layout: true,
        restart: true,
      );
    });

    test('a re-engage while releasing is a takeover, never waiting', () {
      expectStep(
        _step(NativeHandover.releasing),
        NativeHandover.takeover,
        layout: true,
        restart: true,
      );
      expectStep(
        _step(NativeHandover.mirror, nativeUp: true),
        NativeHandover.takeover,
        layout: true,
        restart: true,
      );
    });
  });

  group('waiting and holding (VK-1064)', () {
    test('waits for mine, not for any engaged config', () {
      expectStep(
        _step(NativeHandover.waiting, nativeUp: true),
        NativeHandover.waiting,
        layout: false,
      );
    });

    test('mine, the top not moved: holding', () {
      expectStep(
        _step(NativeHandover.waiting, mine: true, nativeUp: true),
        NativeHandover.holding,
        layout: true,
      );
    });

    test('mine and moved, or no Flutter bar: done', () {
      expectStep(
        _step(NativeHandover.waiting, mine: true, moved: true),
        NativeHandover.done,
        layout: true,
      );
      expectStep(
        _step(NativeHandover.waiting, mine: true, flutterBar: false),
        NativeHandover.done,
        layout: true,
      );
    });

    test('the fallback ends waiting and holding', () {
      expectStep(
        _step(NativeHandover.waiting, timedOut: true),
        NativeHandover.done,
        layout: true,
      );
      expectStep(
        _step(NativeHandover.holding, mine: true, timedOut: true),
        NativeHandover.done,
        layout: true,
      );
    });

    test('holding ends when the top moves', () {
      expectStep(
        _step(NativeHandover.holding, mine: true),
        NativeHandover.holding,
        layout: true,
      );
      expectStep(
        _step(NativeHandover.holding, mine: true, moved: true),
        NativeHandover.done,
        layout: true,
      );
    });
  });

  group('takeover', () {
    test('latches across a state that is not engaged', () {
      expectStep(
        _step(NativeHandover.takeover),
        NativeHandover.takeover,
        layout: true,
      );
    });

    test('a moved top does not end it; mine does', () {
      expectStep(
        _step(NativeHandover.takeover, nativeUp: true, moved: true),
        NativeHandover.takeover,
        layout: true,
      );
      expectStep(
        _step(NativeHandover.takeover, mine: true, nativeUp: true),
        NativeHandover.done,
        layout: true,
      );
    });

    test('with its own Flutter bar drawn, mine hands it over through '
        'holding; moved first, done', () {
      expectStep(
        _step(NativeHandover.takeover, mine: true, barMismatch: true),
        NativeHandover.holding,
        layout: true,
      );
      expectStep(
        _step(
          NativeHandover.takeover,
          mine: true,
          barMismatch: true,
          moved: true,
        ),
        NativeHandover.done,
        layout: true,
      );
    });

    test('a new size or the fallback ends it', () {
      expectStep(
        _step(NativeHandover.takeover, resized: true, moved: true),
        NativeHandover.done,
        layout: true,
      );
      expectStep(
        _step(NativeHandover.takeover, timedOut: true),
        NativeHandover.done,
        layout: true,
      );
    });
  });

  group('a disengage (VK-1074)', () {
    for (final phase in [
      NativeHandover.holding,
      NativeHandover.takeover,
      NativeHandover.done,
    ]) {
      test("from ${phase.name}: releasing keeps native's layout", () {
        expectStep(
          _step(phase, engaged: false),
          NativeHandover.releasing,
          layout: true,
          restart: true,
        );
      });
    }

    test('from waiting: the Flutter layout at once (it never left it)', () {
      expectStep(
        _step(NativeHandover.waiting, engaged: false),
        NativeHandover.none,
        layout: false,
      );
    });

    test('not releasable (another shell owns it now): none', () {
      expectStep(
        _step(NativeHandover.done, engaged: false, releasable: false),
        NativeHandover.none,
        layout: false,
      );
    });

    test('released: the mirror hold of the Flutter bar', () {
      expectStep(
        _step(NativeHandover.releasing, engaged: false, released: true),
        NativeHandover.mirror,
        layout: false,
        restart: true,
      );
      expectStep(
        _step(NativeHandover.done, engaged: false, released: true),
        NativeHandover.mirror,
        layout: false,
        restart: true,
      );
    });

    test('released without a Flutter bar: nothing to hold', () {
      expectStep(
        _step(
          NativeHandover.releasing,
          engaged: false,
          released: true,
          flutterBar: false,
        ),
        NativeHandover.none,
        layout: false,
      );
    });

    test('releasing waits; the fallback or a new size ends it', () {
      expectStep(
        _step(NativeHandover.releasing, engaged: false),
        NativeHandover.releasing,
        layout: true,
      );
      expectStep(
        _step(NativeHandover.releasing, engaged: false, timedOut: true),
        NativeHandover.none,
        layout: false,
      );
      expectStep(
        _step(NativeHandover.releasing, engaged: false, resized: true),
        NativeHandover.none,
        layout: false,
      );
    });

    test('the mirror holds until the top moves or the fallback', () {
      expectStep(
        _step(NativeHandover.mirror, engaged: false, released: true),
        NativeHandover.mirror,
        layout: false,
      );
      expectStep(
        _step(NativeHandover.mirror, engaged: false, moved: true),
        NativeHandover.none,
        layout: false,
      );
      expectStep(
        _step(NativeHandover.mirror, engaged: false, timedOut: true),
        NativeHandover.none,
        layout: false,
      );
    });
  });

  group('nativeConfigShowsPageBar (D3)', () {
    LiquidNativeChromeConfig home(List<LiquidNativePage> pages) =>
        LiquidNativeChromeConfig(
          engaged: true,
          tabs: [
            LiquidNativeTab(title: 'Home', sfSymbol: 'house', pages: pages),
          ],
        );
    const plus = LiquidNativePageAction(sfSymbol: 'plus', label: 'Add');

    test('a tab without pages has no bar', () {
      expect(nativeConfigShowsPageBar(home(const []), compact: true), isFalse);
    });

    test('a default root: a bar on an iPhone, none at regular width', () {
      final config = home(const [LiquidNativePage(title: 'Home')]);
      expect(nativeConfigShowsPageBar(config, compact: true), isTrue);
      expect(nativeConfigShowsPageBar(config, compact: false), isFalse);
    });

    test('a root with actions or a pushed page has one', () {
      expect(
        nativeConfigShowsPageBar(
          home(const [
            LiquidNativePage(title: 'Home', largeTitle: false, actions: [plus]),
          ]),
          compact: false,
        ),
        isTrue,
      );
      expect(
        nativeConfigShowsPageBar(
          home(const [
            LiquidNativePage(title: 'Home', largeTitle: false),
            LiquidNativePage(title: 'Detail'),
          ]),
          compact: false,
        ),
        isTrue,
      );
    });

    test('the search tab always has one; a bad index none', () {
      const search = LiquidNativeChromeConfig(
        engaged: true,
        tabs: [LiquidNativeTab(title: 'Search', sfSymbol: '', search: true)],
      );
      expect(nativeConfigShowsPageBar(search, compact: false), isTrue);
      const bad = LiquidNativeChromeConfig(engaged: true, selectedIndex: 3);
      expect(nativeConfigShowsPageBar(bad, compact: true), isFalse);
    });
  });
}
