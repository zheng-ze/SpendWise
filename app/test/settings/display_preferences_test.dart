import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/settings/display_preferences.dart';

void main() {
  test('constructed collections reject mutation', () {
    final preferences = DisplayPreferences(
      overviewWidgets: [OverviewWidgetKind.today],
      dismissedInsights: {'2026-10:x'},
    );

    expect(
      () => preferences.overviewWidgets.add(OverviewWidgetKind.comingUp),
      throwsUnsupportedError,
    );
    expect(
      () => preferences.dismissedInsights.add('2026-11:y'),
      throwsUnsupportedError,
    );
  });
}
