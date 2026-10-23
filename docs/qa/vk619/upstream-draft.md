Draft for the owner. **Not to be posted: upstream already has it** (checked 2026-10-21).

- [flutter/flutter#191565](https://github.com/flutter/flutter/issues/191565), open since 2026-08-24, `P2`, `team-ios`, `triaged-ios`. It covers everything below and more: the same root cause and fix, swizzle logs of which view got `scrollViewShouldScrollToTop:`, a video, an app-side workaround, and a repro on an iPhone 15 Pro (iOS 26.6) under Speak Screen, on Flutter 3.47.1, newer than the 3.44.6 run here.
- [flutter/flutter#191833](https://github.com/flutter/flutter/pull/191833), a draft PR that sets `scrollsToTop = NO` on the mirror. Triage leaned instead towards the mirror forwarding the tap to `FlutterViewController`, and the PR has waited since 2026-08-26 for that choice.
- The search under "Not verified" below missed both: a query with both words, "FlutterSemanticsScrollView scrollsToTop", returns nothing; "FlutterSemanticsScrollView" alone finds them.

This file stays as the record of this project's simulator repro. Follow #191565 and #191833 instead of posting. The draft below is kept as it was written: its "before posting" notes (the line check, the device check, the duplicate search) no longer apply.

# [iOS] FlutterSemanticsScrollView leaves scrollsToTop on, so a status-bar tap scrolls the accessibility mirror instead of the Flutter list

## Summary

While the iOS accessibility bridge is on (always in the simulator; on a device under VoiceOver, Switch Control or Speak Screen), every scrollable semantics node gets a `FlutterSemanticsScrollView`, a `UIScrollView` that mirrors it for assistive technology. The engine never sets its `scrollsToTop`, so UIKit's default, YES, stays. Flutter's own status-bar scroll view (the one whose `scrollViewShouldScrollToTop:` calls `onStatusBarTap`) has `scrollsToTop` YES too.

UIKit gives a status-bar tap to the mirror: it animates the mirror to offset 0, and the Flutter list does not move. In a plain `flutter create` app with a 100-row `ListView`, scrolled down, one status-bar tap does not bring the list back to the top. It takes three taps in the run below. With `scrollsToTop = false` set on the mirror from the app, one tap is enough.

## Environment

- **Flutter:** 3.44.6, stable, engine 83675ed276. *(Check the lines below against the current stable before posting.)*
- **Xcode:** 27.1 (27A9275). **Simulator:** iPhone 17, iOS 26.5 (runtime 23F77). macOS: Darwin 25.6.0, Apple silicon.
- **Project:** `flutter create --platforms ios`, default template (Material, no plugins). The Runner target's deployment target raised from the template's 13.0 to 15.0, which Xcode 27 requires.
- **Device:** not checked. The report is from the simulator, where the bridge is always on. On a device it should affect VoiceOver, Switch Control and Speak Screen users (`FlutterViewController.mm:2190-2191`). *(Unverified. The owner checks it before posting.)*

## Steps to reproduce

1. `flutter create --platforms ios sbtap`, then replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: ListPage()));

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView.builder(
      itemCount: 100,
      itemBuilder: (context, i) => SizedBox(height: 56, child: Center(child: Text('Row $i'))),
    ),
  );
}
```

2. In Xcode, open `ios/Runner.xcworkspace`, set the Runner target's iOS Deployment Target to 15.0, add a UI Testing Bundle target named `RunnerUITests`, and make sure the Runner scheme's Test action lists it. Put this in `RunnerUITests/StatusBarTapUITests.swift`. Semantics are on under XCUITest and always on in a simulator, so the app needs no `ensureSemantics()`.

```swift
import XCTest

final class StatusBarTapUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Launches the app, scrolls the 100-row list away from "Row 0", and
  /// returns the app.
  private func appScrolledDown(_ extra: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += extra
    app.launch()
    let first = app.staticTexts["Row 0"]
    XCTAssertTrue(first.waitForExistence(timeout: 30), "the list is up")
    for _ in 0..<8 { app.swipeUp(velocity: .fast) }
    // Row 0 is built only near the viewport: gone means scrolled away.
    XCTAssertFalse(first.exists, "the list scrolled away from Row 0")
    return app
  }

  private func tapStatusBar(_ app: XCUIApplication) {
    // XCUITest finds no StatusBar element on iOS 26, so tap the status bar's
    // coordinates, clear of the Dynamic Island.
    let window = app.windows.firstMatch
    window.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: window.frame.width * 0.85, dy: 15))
      .tap()
  }

  /// One status-bar tap should scroll the Flutter list to the top.
  func testOneStatusBarTapScrollsTheListToTheTop() {
    let app = appScrolledDown()
    tapStatusBar(app)
    XCTAssertTrue(
      app.staticTexts["Row 0"].waitForExistence(timeout: 5),
      "after ONE status-bar tap the list is back at Row 0")
  }

  /// Documents the symptom: the number of taps the list needs is printed
  /// ("VK619 taps needed: N"). One tap is enough only when the bug is gone.
  func testTheListNeedsMoreThanOneStatusBarTap() {
    let app = appScrolledDown(["-dumpScrollViews"])
    var taps = 0
    var reached = false
    while taps < 6, !reached {
      tapStatusBar(app)
      taps += 1
      reached = app.staticTexts["Row 0"].waitForExistence(timeout: 8)
      let rows = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Row '"))
      print("VK619 after tap \(taps): first built row = \(rows.firstMatch.label)")
    }
    print("VK619 taps needed: \(reached ? String(taps) : "more than 6")")
    XCTAssertTrue(reached, "Row 0 came back within 6 taps")
    XCTAssertGreaterThan(taps, 1, "taps needed to reach Row 0")
  }

  /// Control: the suggested fix applied from the app (scrollsToTop = false on
  /// every FlutterSemanticsScrollView), so one tap reaches Flutter.
  func testOneTapWorksWhenTheMirrorDoesNotTakeScrollsToTop() {
    let app = appScrolledDown(["-mirrorScrollsToTopOff"])
    tapStatusBar(app)
    XCTAssertTrue(
      app.staticTexts["Row 0"].waitForExistence(timeout: 5),
      "control: one tap, mirror scrollsToTop off")
  }
}
```

3. For the control test, and for the table under "Actual", add this to the app's `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, before `return super…`. Without it the two launch arguments do nothing.

<details>
<summary>AppDelegate additions</summary>

```swift
if CommandLine.arguments.contains("-mirrorScrollsToTopOff") {
  // The suggested fix, applied from the app. The mirror is created lazily,
  // once semantics updates arrive.
  Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
    for scene in UIApplication.shared.connectedScenes {
      for window in (scene as? UIWindowScene)?.windows ?? [] {
        Self.clearScrollsToTop(in: window)
      }
    }
  }
}
if CommandLine.arguments.contains("-dumpScrollViews") {
  // Every UIScrollView (class, scrollsToTop, offset, frame) whenever one of
  // them changes, to a file the host can read (a simulator shares the host's
  // file system).
  var last = ""
  let path = "/tmp/vk619-scrollviews.txt"
  try? "".write(toFile: path, atomically: true, encoding: .utf8)
  Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
    var lines: [String] = []
    for scene in UIApplication.shared.connectedScenes {
      for window in (scene as? UIWindowScene)?.windows ?? [] {
        Self.collect(window, into: &lines)
      }
    }
    let text = lines.joined(separator: "\n")
    guard text != last else { return }
    last = text
    let stamp = String(format: "%.2f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
    if let h = FileHandle(forWritingAtPath: path) {
      h.seekToEndOfFile()
      h.write("--- \(stamp)\n\(text)\n".data(using: .utf8)!)
      h.closeFile()
    }
  }
}
```

and, in the same class:

```swift
private static func collect(_ view: UIView, into lines: inout [String]) {
  if let scroll = view as? UIScrollView {
    lines.append(
      "\(type(of: scroll)) scrollsToTop=\(scroll.scrollsToTop) offset=\(scroll.contentOffset) frame=\(scroll.frame)")
  }
  for sub in view.subviews { collect(sub, into: &lines) }
}

private static func clearScrollsToTop(in view: UIView) {
  if let scroll = view as? UIScrollView,
    String(describing: type(of: scroll)) == "FlutterSemanticsScrollView"
  {
    scroll.scrollsToTop = false
  }
  for sub in view.subviews { clearScrollsToTop(in: sub) }
}
```

</details>

4. `flutter build ios --config-only --simulator --debug`, then, from `ios/`:

```
xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,id=<udid of an iPhone 17, iOS 26.5>' \
  -only-testing:RunnerUITests
```

## Expected

One status-bar tap scrolls the list to the top, as it does with a Flutter app that has no accessibility mirror, and as it does in the control run.

## Actual

`testOneStatusBarTapScrollsTheListToTheTop` fails: after one tap `Row 0` does not come back within 5 s. The same run, with the same result each time (3 runs):

```
VK619 after tap 1: first built row = Row 81
VK619 after tap 2: first built row = Row 81
VK619 after tap 3: first built row = Row 0
VK619 taps needed: 3
```

so the list is still where it was after two taps, and the third reaches it. The control test (`-mirrorScrollsToTopOff`) passes with one tap.

The scroll views in the window while the list is scrolled (from `-dumpScrollViews`):

| Class | scrollsToTop | Frame | Offset |
|---|---|---|---|
| `FlutterSemanticsScrollView` (the mirror) | true | the screen, 402 × 874 | y 4822, the list's offset |
| `UIScrollView` (Flutter's status-bar view) | true | 402 × 0 | (2, 2) |

On the taps that were dumped, the mirror's offset animates from 4822 to 0 in about 1.2 s at the first tap (run 1, sampled every 0.2 s, the first sample is mid-animation: 1119, 176, 30, 5, 1, 0.3, 0; the other two runs ended the same way) and the list does not move. The mirror then animates to 0 a second time, from a large nonzero offset again (first sample 1229, 2461 and 1361 in the three runs), so something put it back up in between; after that second animation it stays at 0, there is no animation after the third tap, and the third tap reaches Flutter. I did not find out what puts the mirror back in between, or why an earlier look at a different app with the same engine, with lldb instead of a dump, counted 2 taps.

## Where it happens

`engine/src/flutter/shell/platform/darwin/ios/framework/Source/` at 83675ed276 (Flutter 3.44.6):

- `SemanticsObject.mm:150-160`: `FlutterScrollableSemanticsObject initWithBridge:uid:` creates the mirror (`:154`), sets the indicators and the insets, and adds it to the bridge's view (`:159`). `scrollsToTop` is not set here or anywhere else in the engine's iOS sources (`grep -rn scrollsToTop` over `Source/` finds nothing), so UIKit's default stays.
- `FlutterSemanticsScrollView.mm:14-22`: the init. The view is its own delegate (`:19`), and the file has no `scrollViewShouldScrollToTop:`, so UIKit's default (allow) applies.
- `FlutterViewController.mm:524-543` (`loadView`) creates Flutter's status-bar scroll view (a 2 × 2 content size, offset (2, 2), `scrollsToTop` at its default YES), and `:557-565` is its `scrollViewShouldScrollToTop:`: `[self.engine onStatusBarTap]`, then NO.
- `FlutterViewController.mm:2183-2191` (`onAccessibilityStatusChanged:`): the bridge is always on in a simulator (`TARGET_OS_SIMULATOR`), and on a device under VoiceOver, Switch Control or Speak Screen.

## Suggested fix

Set `scrollsToTop` to NO on the mirror, in the init in `SemanticsObject.mm`:

```objc
_scrollView = [[FlutterSemanticsScrollView alloc] initWithSemanticsObject:self];
_scrollView.scrollsToTop = NO;  // the status-bar tap belongs to FlutterViewController's own view
```

The mirror exists only for assistive technology, which scrolls it through accessibility actions, not through the status bar, so nothing needs its `scrollsToTop`.

## Not verified

- **A patched engine.** The control run sets the property from the app after the mirror exists; it shows that the property decides the outcome in this app, not that the engine change builds or has no other effect.
- **A physical device** under VoiceOver and Speak Screen: whether one tap misses there too, and how many taps it takes. *(The owner does this before posting; it does not block the PR that adds this draft.)*
- **Other OS and Xcode versions.** Only iOS 26.5 with Xcode 27.1 was run.
- **A duplicate issue.** A search of flutter/flutter for "FlutterSemanticsScrollView scrollsToTop" and "status bar tap scroll to top semantics iOS" found nothing when this project looked for it first. *(The search again on 2026-10-21 found #191565 and #191833: see the top of this file.)*
