/// How a glass surface is drawn, from richest to plainest.
enum LiquidGlassTier {
  /// Refracting glass: the built-in lens shader (Impeller), or a
  /// registered renderer.
  liquid,

  /// Blurred backdrop with a tint, border, rim highlight and shadow.
  frosted,

  /// Opaque fill. Used when accessibility or power signals ask for it.
  solid,
}
