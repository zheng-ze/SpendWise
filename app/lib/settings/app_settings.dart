import 'package:shared_preferences/shared_preferences.dart';

const _scanStripEnabledKey = 'scanStripEnabled';

/// Persisted app settings.
class AppSettings {
  const AppSettings();

  /// Whether the new-entry form shows the scan/upload strip. Defaults to
  /// true when nothing has been saved yet.
  Future<bool> scanStripEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scanStripEnabledKey) ?? true;
  }

  Future<void> setScanStripEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scanStripEnabledKey, value);
  }
}
