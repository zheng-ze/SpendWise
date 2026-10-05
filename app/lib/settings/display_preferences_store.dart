import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/settings/display_preferences.dart';

class DisplayPreferencesStore {
  DisplayPreferencesStore(this.prefs);

  final SharedPreferences prefs;

  static const appearanceKey = 'display.v1.appearance';
  static const overviewWidgetsKey = 'display.v1.overviewWidgets';
  static const breakdownChartKey = 'display.v1.breakdownChart';
  static const breakdownLevelKey = 'display.v1.breakdownLevel';
  static const chartColoursKey = 'display.v1.chartColours';
  static const insightCategoryChangesKey =
      'display.v1.insights.categoryChanges';
  static const insightUsualPaceKey = 'display.v1.insights.usualPace';
  static const dismissedInsightsKey = 'display.v1.insights.dismissed';
  static const savingsPocketKey = 'display.v1.savingsPocket';

  DisplayPreferences load() {
    final widgetsRaw = prefs.getString(overviewWidgetsKey);
    return DisplayPreferences(
      appearance: Appearance.decode(prefs.getString(appearanceKey)),
      overviewWidgets: widgetsRaw == null
          ? DisplayPreferences.defaults.overviewWidgets
          : _decodeWidgets(widgetsRaw),
      breakdownChart: BreakdownChart.decode(prefs.getString(breakdownChartKey)),
      breakdownLevel: BreakdownLevel.decode(prefs.getString(breakdownLevelKey)),
      chartColours: ChartColours.decode(prefs.getString(chartColoursKey)),
      insightCategoryChanges: prefs.getBool(insightCategoryChangesKey) ?? true,
      insightUsualPace: prefs.getBool(insightUsualPaceKey) ?? true,
      dismissedInsights: Set.of(
        prefs.getStringList(dismissedInsightsKey) ?? const [],
      ),
      savingsPocketID: prefs.getString(savingsPocketKey),
    );
  }

  Future<void> save(DisplayPreferences preferences) async {
    await prefs.setString(appearanceKey, preferences.appearance.code);
    await prefs.setString(
      overviewWidgetsKey,
      preferences.overviewWidgets.map((widget) => widget.code).join(','),
    );
    await prefs.setString(breakdownChartKey, preferences.breakdownChart.code);
    await prefs.setString(breakdownLevelKey, preferences.breakdownLevel.code);
    await prefs.setString(chartColoursKey, preferences.chartColours.code);
    await prefs.setBool(
      insightCategoryChangesKey,
      preferences.insightCategoryChanges,
    );
    await prefs.setBool(insightUsualPaceKey, preferences.insightUsualPace);
    await prefs.setStringList(
      dismissedInsightsKey,
      preferences.dismissedInsights.toList()..sort(),
    );
    final pocketID = preferences.savingsPocketID;
    if (pocketID == null) {
      await prefs.remove(savingsPocketKey);
    } else {
      await prefs.setString(savingsPocketKey, pocketID);
    }
  }

  static List<OverviewWidgetKind> _decodeWidgets(String raw) {
    if (raw.isEmpty) return const [];
    final seen = <OverviewWidgetKind>{};
    final widgets = <OverviewWidgetKind>[];
    for (final code in raw.split(',')) {
      final widget = OverviewWidgetKind.tryDecode(code);
      if (widget == null || !seen.add(widget)) continue;
      widgets.add(widget);
    }
    return widgets;
  }
}
