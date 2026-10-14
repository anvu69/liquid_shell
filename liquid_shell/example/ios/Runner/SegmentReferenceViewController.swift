#if DEBUG
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// DEBUG only, public UIKit API only (spec VK-550 §13, §14.5): UIKit's own
/// `UISegmentedControl`s at the frames of the Flutter segments case
/// (`lib/cases/segments.dart`, `kSegmentsRows`), over the same stripes, so
/// tool/segment_frames.sh can record native and Flutter side by side.
/// Shown instead of Flutter when the example is launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=segments-native.
final class SegmentReferenceViewController: UIViewController {
  /// One control: its accessibility identifier, titles, full width (or
  /// centred at its intrinsic width), enabled, and its top in points from
  /// the top of the screen. Keep in step with `kSegmentsRows`.
  private static let controls: [(id: String, items: [String], fullWidth: Bool, enabled: Bool, top: CGFloat)] = [
    ("intrinsic3", ["All", "Songs", "Places"], false, true, 160),
    ("full3", ["All", "Songs", "Places"], true, true, 240),
    ("full2", ["Songs", "Places"], true, true, 320),
    ("full5", ["One", "Two", "Three", "Four", "Five"], true, true, 400),
    ("disabled3", ["All", "Songs", "Places"], true, false, 480),
  ]

  /// The control "Next segment" moves, as the Flutter case's.
  private var full3: UISegmentedControl?

  /// full3's last touch as UIKit delivered it, for SegmentFidelityUITests
  /// (a requested XCUITest speed is not the speed delivered).
  private let touchLog: UILabel = {
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
    label.textColor = .clear
    label.isUserInteractionEnabled = false
    label.accessibilityIdentifier = "segfid-touch"
    label.accessibilityLabel = "none"
    return label
  }()

  override func loadView() {
    view = StripesView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // 16 pt margins on every device, as the Flutter case's.
    viewRespectsSystemMinimumLayoutMargins = false
    view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    for control in Self.controls {
      let segmented = UISegmentedControl(items: control.items)
      segmented.selectedSegmentIndex = 0
      segmented.isEnabled = control.enabled
      segmented.accessibilityIdentifier = control.id
      segmented.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(segmented)
      var constraints = [segmented.topAnchor.constraint(equalTo: view.topAnchor, constant: control.top)]
      if control.fullWidth {
        constraints += [
          segmented.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
          segmented.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ]
      } else {
        constraints.append(segmented.centerXAnchor.constraint(equalTo: view.centerXAnchor))
      }
      NSLayoutConstraint.activate(constraints)
      if control.id == "full3" {
        full3 = segmented
        segmented.addGestureRecognizer(TouchLog(label: touchLog))
      }
    }
    view.addSubview(touchLog)
    // The app's own change, as the Flutter case's "Next segment, from
    // code": UIKit slides the selection and sends no valueChanged.
    let next = UIButton(
      configuration: .filled(),
      primaryAction: UIAction(title: "Next segment, from code") { [weak self] _ in
        guard let control = self?.full3 else { return }
        control.selectedSegmentIndex = (control.selectedSegmentIndex + 1) % control.numberOfSegments
      })
    next.accessibilityIdentifier = "segments-next"
    next.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(next)
    NSLayoutConstraint.activate([
      next.topAnchor.constraint(equalTo: view.topAnchor, constant: 560),
      next.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
    ])
  }

  /// Presents the screen full screen, without animation, over the Flutter
  /// view once the app's scene is active. Flutter keeps running under it.
  static func showWhenActive() {
    // Kept for the app's life: the screen shows once.
    _ = NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification, object: nil, queue: .main
    ) { note in
      MainActor.assumeIsolated { present(over: note.object as? UIWindowScene) }
    }
  }

  private static var presented = false

  private static func present(over scene: UIWindowScene?) {
    guard
      !presented,
      let root = (scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first)?
        .rootViewController
    else { return }
    presented = true
    let screen = SegmentReferenceViewController()
    screen.modalPresentationStyle = .fullScreen
    root.present(screen, animated: false)
  }
}

/// Writes each touch on its view to [label]'s accessibility label as
/// "<seconds> <from x> <to x>": down to up on UIKit's touch clock, x in the
/// view. Passive: it never recognizes, cancels or delays a touch, and
/// recognizes alongside every other recognizer.
private final class TouchLog: UIGestureRecognizer, UIGestureRecognizerDelegate {
  private let label: UILabel
  private var start: (time: TimeInterval, x: CGFloat)?

  init(label: UILabel) {
    self.label = label
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
    delegate = self
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    guard let touch = touches.first, let view else { return }
    start = (touch.timestamp, touch.location(in: view).x)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    if let start, let touch = touches.first, let view {
      label.accessibilityLabel = String(
        format: "%.3f %.1f %.1f", touch.timestamp - start.time, start.x,
        touch.location(in: view).x)
    }
    start = nil
    state = .failed
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    start = nil
    state = .failed
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
  ) -> Bool { true }
}

/// The VK-550 spike's `PatternView` stripes: bands 20 pt tall every 40 pt,
/// falling 45° to the right, over the system background, in the eight
/// system colours. `SegmentsStripesPainter` draws the same in Flutter.
private final class StripesView: UIView {
  private static let colours: [UIColor] = [
    .systemRed, .systemOrange, .systemYellow, .systemGreen,
    .systemTeal, .systemBlue, .systemPurple, .systemPink,
  ]

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .systemBackground
    contentMode = .redraw
  }

  required init?(coder: NSCoder) { fatalError("not used") }

  // UIKit redraws a view that draws itself when the appearance changes, so
  // the dynamic system colours follow light and dark.

  override func draw(_ rect: CGRect) {
    let pitch: CGFloat = 40
    let width = bounds.width
    let count = Self.colours.count
    var i = Int(floor((rect.minY - width) / pitch))
    while CGFloat(i) * pitch < rect.maxY + pitch {
      Self.colours[(i % count + count) % count].setFill()
      let top = CGFloat(i) * pitch
      let band = UIBezierPath()
      band.move(to: CGPoint(x: 0, y: top))
      band.addLine(to: CGPoint(x: width, y: top + width))
      band.addLine(to: CGPoint(x: width, y: top + width + pitch / 2))
      band.addLine(to: CGPoint(x: 0, y: top + pitch / 2))
      band.close()
      band.fill()
      i += 1
    }
  }
}
#endif
