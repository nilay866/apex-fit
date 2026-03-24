/// Apex AI Design Token — Spacing & Radius
///
/// Use these constants instead of hardcoded pixel values to keep
/// layouts consistent across all screens and components.
///
/// Usage:
///   SizedBox(height: AppSpacing.md)
///   BorderRadius.circular(AppRadius.lg)

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  /// Standard horizontal page padding
  static const double pagePadding = 16.0;

  /// Bottom padding for scrollable lists (above nav bar)
  static const double listBottom = 100.0;
}

class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  /// Fully-rounded pill shape
  static const double full = 999.0;
}
