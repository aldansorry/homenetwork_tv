/// Utility class for URL validation
class UrlValidator {
  UrlValidator._(); // Private constructor to prevent instantiation

  /// Validate if string is a valid HTTP/HTTPS URL
  static bool isValidHttpUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Normalize URL by removing trailing slash
  static String normalizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/$'), '');
  }

  /// Validate and normalize URL
  /// Returns null if URL is invalid
  static String? validateAndNormalize(String url) {
    if (!isValidHttpUrl(url)) {
      return null;
    }
    return normalizeUrl(url);
  }
}

