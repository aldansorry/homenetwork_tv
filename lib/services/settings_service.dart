import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _backendUrlKey = 'backend_url';
  static const String _defaultBackendUrl = 'http://localhost:3000';

  // Get backend URL from settings
  static Future<String> getBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_backendUrlKey) ?? _defaultBackendUrl;
    } catch (e) {
      print('Error getting backend URL: $e');
      return _defaultBackendUrl;
    }
  }

  // Set backend URL in settings
  static Future<bool> setBackendUrl(String url) async {
    try {
      // Validate URL format
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return false;
      }

      // Remove trailing slash
      url = url.trim();
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_backendUrlKey, url);
    } catch (e) {
      print('Error setting backend URL: $e');
      return false;
    }
  }

  // Get backend URL synchronously (returns default if not loaded yet)
  static String getBackendUrlSync() {
    return _defaultBackendUrl;
  }

  // Reset to default
  static Future<bool> resetBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_backendUrlKey);
    } catch (e) {
      print('Error resetting backend URL: $e');
      return false;
    }
  }
}

