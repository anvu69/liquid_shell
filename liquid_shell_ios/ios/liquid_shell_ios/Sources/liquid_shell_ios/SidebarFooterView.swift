import UIKit

/// The native sidebar footer (`sidebar.bottomBarView`, spec §4.3). It has to
/// be UIKit: a Flutter widget cannot live in the sidebar without a second
/// engine. Dart sends its content.
@available(iOS 26.0, *)
final class SidebarFooterView: UIControl {
  var onTap: (() -> Void)?

  private let icon = UIImageView()
  private let title = UILabel()
  private let subtitle = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
    icon.tintColor = .tintColor
    // Without these the row gives the spare width to the image and
    // `.scaleToFill` squashes the symbol.
    icon.contentMode = .scaleAspectFit
    icon.setContentHuggingPriority(.required, for: .horizontal)
    icon.setContentCompressionResistancePriority(.required, for: .horizontal)
    title.font = .preferredFont(forTextStyle: .headline)
    title.adjustsFontForContentSizeCategory = true
    subtitle.font = .preferredFont(forTextStyle: .footnote)
    subtitle.textColor = .secondaryLabel
    subtitle.adjustsFontForContentSizeCategory = true

    let texts = UIStackView(arrangedSubviews: [title, subtitle])
    texts.axis = .vertical
    let row = UIStackView(arrangedSubviews: [icon, texts])
    row.spacing = 12
    row.alignment = .center
    row.isUserInteractionEnabled = false
    row.translatesAutoresizingMaskIntoConstraints = false
    addSubview(row)
    directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
    // The sidebar sizes the footer with systemLayoutSizeFitting.
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
      row.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
      row.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
    ])

    isAccessibilityElement = true
    accessibilityTraits = .button
    addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  func update(_ data: NativeFooter) {
    icon.image = UIImage(systemName: data.sfSymbol)
    title.text = data.title
    subtitle.text = data.subtitle
    accessibilityLabel = data.semanticLabel
  }

  override var isHighlighted: Bool {
    didSet { alpha = isHighlighted ? 0.5 : 1 }
  }

  override func accessibilityActivate() -> Bool {
    onTap?()
    return true
  }
}
