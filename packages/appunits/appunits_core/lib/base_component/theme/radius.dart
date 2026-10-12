final RadiusScheme = SemanticRadiusScheme(
  tipsRadius: _Radius.radius4,
  smallRadius: _Radius.radius8,
  alertRadius: _Radius.radius12,
  largeRadius: _Radius.radius16,
  superLargeRadius: _Radius.radius20,
  roundRadius: _Radius.radius999,
);

class SemanticRadiusScheme {
  final double tipsRadius;
  
  final double smallRadius;
  
  final double alertRadius;
  
  final double largeRadius;
  
  final double superLargeRadius;
  
  final double roundRadius;

  const SemanticRadiusScheme({
    required this.tipsRadius,
    required this.smallRadius,
    required this.alertRadius,
    required this.largeRadius,
    required this.superLargeRadius,
    required this.roundRadius,
  });
}

class _Radius {
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius999 = 999.0;
} 