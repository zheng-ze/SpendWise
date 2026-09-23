import 'package:shared_preferences/shared_preferences.dart';

const _scanStripEnabledKey = 'scanStripEnabled';

class AppSettings {
  const AppSettings();

  Future<bool> scanStripEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scanStripEnabledKey) ?? true;
  }

  Future<void> setScanStripEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scanStripEnabledKey, value);
  }
}
