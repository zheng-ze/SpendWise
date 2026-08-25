import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/settings/app_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSettings.scanStripEnabled', () {
    test('defaults to true when nothing has been saved', () async {
      final settings = AppSettings();

      expect(await settings.scanStripEnabled(), isTrue);
    });

    test('round-trips a value written with setScanStripEnabled', () async {
      final settings = AppSettings();

      await settings.setScanStripEnabled(false);
      expect(await settings.scanStripEnabled(), isFalse);

      await settings.setScanStripEnabled(true);
      expect(await settings.scanStripEnabled(), isTrue);
    });
  });
}
