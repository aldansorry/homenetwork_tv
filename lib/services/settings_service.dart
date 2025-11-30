import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../utils/url_validator.dart';

/// Service for managing application settings
class SettingsService {
  SettingsService._(); // Private constructor to prevent instantiation

  /// Get backend URL from settings
  /// Returns default URL if not set or on error
  static Future<String> getBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.settingsKeyBackendUrl) ??
          AppConstants.defaultBackendUrl;
    } catch (e) {
      print('Error getting backend URL: $e');
      return AppConstants.defaultBackendUrl;
    }
  }

  /// Set backend URL in settings
  /// Returns true if successful, false otherwise
  static Future<bool> setBackendUrl(String url) async {
    try {
      final normalizedUrl = UrlValidator.validateAndNormalize(url);
      if (normalizedUrl == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        AppConstants.settingsKeyBackendUrl,
        normalizedUrl,
      );
    } catch (e) {
      print('Error setting backend URL: $e');
      return false;
    }
  }

  /// Get backend URL synchronously (returns default if not loaded yet)
  /// Note: This is a fallback method, prefer using getBackendUrl() async
  static String getBackendUrlSync() {
    return AppConstants.defaultBackendUrl;
  }

  /// Reset backend URL to default
  /// Returns true if successful, false otherwise
  static Future<bool> resetBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(AppConstants.settingsKeyBackendUrl);
    } catch (e) {
      print('Error resetting backend URL: $e');
      return false;
    }
  }
}

