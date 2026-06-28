import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String defaultBackendUrl = 'http://node2.gervhosting.my.id:5587';
  static const String localBackendUrl = 'http://10.0.2.2:8000'; // Android emulator
  static const String localBackendUrlDesktop = 'http://127.0.0.1:8000'; // Windows/desktop

  static const String _prefKey = 'backend_url';

  /// Get saved backend URL, fallback to default
  static Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? defaultBackendUrl;
  }

  /// Save backend URL
  static Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, url.replaceAll(RegExp(r'/$'), ''));
  }

  /// Reset to default
  static Future<void> resetBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
