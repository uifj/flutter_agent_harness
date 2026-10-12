final SpacingScheme = SemanticSpacingScheme(
  iconTextSpacing: _Spacings.spacing4,
  smallSpacing: _Spacings.spacing8,
  iconIconSpacing: _Spacings.spacing12,
  bubbleSpacing: _Spacings.spacing16,
  contentSpacing: _Spacings.spacing20,
  normalSpacing: _Spacings.spacing24,
  titleSpacing: _Spacings.spacing32,
  cardSpacing: _Spacings.spacing40,
  largeSpacing: _Spacings.spacing56,
  maxSpacing: _Spacings.spacing72,
);

class SemanticSpacingScheme {
  final double iconTextSpacing;
  
  final double smallSpacing;
  
  final double iconIconSpacing;
  
  final double bubbleSpacing;
  
  final double contentSpacing;
  
  final double normalSpacing;
  
  final double titleSpacing;
  
  final double cardSpacing;
  
  final double largeSpacing;
  
  final double maxSpacing;

  const SemanticSpacingScheme({
    required this.iconTextSpacing,
    required this.smallSpacing,
    required this.iconIconSpacing,
    required this.bubbleSpacing,
    required this.contentSpacing,
    required this.normalSpacing,
    required this.titleSpacing,
    required this.cardSpacing,
    required this.largeSpacing,
    required this.maxSpacing,
  });
}

class _Spacings {
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing56 = 56.0;
  static const double spacing72 = 72.0;
} 