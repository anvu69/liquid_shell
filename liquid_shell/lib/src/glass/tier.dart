/// How a glass surface is drawn, from richest to plainest.
enum LiquidGlassTier {
  /// Refracting glass. Needs a registered renderer (none ships in this
  /// package yet).
  liquid,

  /// Blurred backdrop with a tint, border, rim highlight and shadow.
  frosted,

  /// Opaque fill. Used when accessibility or power signals ask for it.
  solid,
}
