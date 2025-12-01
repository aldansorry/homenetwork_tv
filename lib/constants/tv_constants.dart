/// Constants optimized for TV viewing
class TvConstants {
  TvConstants._(); // Private constructor to prevent instantiation

  // TV-optimized sizes (larger for viewing distance)
  static const double tvFontSizeTitle = 32.0;
  static const double tvFontSizeSubtitle = 24.0;
  static const double tvFontSizeBody = 20.0;
  static const double tvFontSizeSmall = 16.0;

  // Spacing for TV
  static const double tvSpacingSmall = 1.0;
  static const double tvSpacingMedium = 24.0;
  static const double tvSpacingLarge = 32.0;
  static const double tvSpacingXLarge = 48.0;

  // Button sizes for TV
  static const double tvButtonHeight = 64.0;
  static const double tvButtonMinWidth = 200.0;
  static const double tvIconSize = 32.0;
  static const double tvIconSizeLarge = 48.0;

  // Card sizes
  static const double tvCardHeight = 300.0;
  static const double tvCardPadding = 24.0;

  // Grid layout for TV
  static const int tvGridCrossAxisCount = 8; // Fewer items per row for TV
  static const double tvGridSpacing = 12.0;
  static const double tvGridAspectRatio = 2;

  // Focus indicator
  static const double tvFocusBorderWidth = 4.0;
  static const int tvFocusColor = 0xFFFF0000;
  static const int tvFocusColorSecondary = 0xFFFF6B6B;

  // Safe area padding for TV
  static const double tvSafeAreaPadding = 48.0;
}
