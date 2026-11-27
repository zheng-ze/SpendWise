import 'package:flutter/foundation.dart';

// MARK: - Appearance

enum Appearance {
  system('system'),
  light('light'),
  dark('dark');

  const Appearance(this.code);

  final String code;

  static Appearance decode(String? code) => Appearance.values.firstWhere(
    (value) => value.code == code,
    orElse: () => Appearance.system,
  );
}

// MARK: - Overview Widgets

enum OverviewWidgetKind {
  today('today'),
  thisMonth('thisMonth'),
  recentEntries('recentEntries'),
  topCategories('topCategories'),
  cardStatement('cardStatement'),
  comingUp('comingUp'),
  accountBalances('accountBalances'),
  spendingOverTime('spendingOverTime'),
  savingsPocket('savingsPocket'),
  budgetWatch('budgetWatch'),
  insights('insights'),
  weekSoFar('weekSoFar');

  const OverviewWidgetKind(this.code);

  final String code;

  static OverviewWidgetKind? tryDecode(String code) => OverviewWidgetKind.values
      .where((value) => value.code == code)
      .firstOrNull;
}

// MARK: - Breakdown Chart

enum BreakdownChart {
  donut('donut'),
  categoryMap('categoryMap');

  const BreakdownChart(this.code);

  final String code;

  static BreakdownChart decode(String? code) =>
      BreakdownChart.values.firstWhere(
        (value) => value.code == code,
        orElse: () => BreakdownChart.donut,
      );
}

// MARK: - Breakdown Level

enum BreakdownLevel {
  categories('categories'),
  subcategories('subcategories');

  const BreakdownLevel(this.code);

  final String code;

  static BreakdownLevel decode(String? code) =>
      BreakdownLevel.values.firstWhere(
        (value) => value.code == code,
        orElse: () => BreakdownLevel.categories,
      );
}

// MARK: - Chart Colours

enum ChartColours {
  categoryColours('categoryColours'),
  themeShades('themeShades'),
  contrasting('contrasting');

  const ChartColours(this.code);

  final String code;

  static ChartColours decode(String? code) => ChartColours.values.firstWhere(
    (value) => value.code == code,
    orElse: () => ChartColours.categoryColours,
  );
}

// MARK: - Preferences

class DisplayPreferences {
  DisplayPreferences({
    this.appearance = Appearance.system,
    List<OverviewWidgetKind> overviewWidgets = const [
      OverviewWidgetKind.today,
      OverviewWidgetKind.thisMonth,
      OverviewWidgetKind.recentEntries,
      OverviewWidgetKind.comingUp,
      OverviewWidgetKind.budgetWatch,
    ],
    this.breakdownChart = BreakdownChart.donut,
    this.breakdownLevel = BreakdownLevel.categories,
    this.chartColours = ChartColours.categoryColours,
    this.savingsPocketID,
  }) : overviewWidgets = List.unmodifiable(overviewWidgets);

  static final defaults = DisplayPreferences();

  final Appearance appearance;
  final List<OverviewWidgetKind> overviewWidgets;
  final BreakdownChart breakdownChart;
  final BreakdownLevel breakdownLevel;
  final ChartColours chartColours;
  final String? savingsPocketID;

  DisplayPreferences copyWith({
    Appearance? appearance,
    List<OverviewWidgetKind>? overviewWidgets,
    BreakdownChart? breakdownChart,
    BreakdownLevel? breakdownLevel,
    ChartColours? chartColours,
    String? Function()? savingsPocketID,
  }) {
    return DisplayPreferences(
      appearance: appearance ?? this.appearance,
      overviewWidgets: overviewWidgets ?? this.overviewWidgets,
      breakdownChart: breakdownChart ?? this.breakdownChart,
      breakdownLevel: breakdownLevel ?? this.breakdownLevel,
      chartColours: chartColours ?? this.chartColours,
      savingsPocketID: savingsPocketID == null
          ? this.savingsPocketID
          : savingsPocketID(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DisplayPreferences &&
      other.appearance == appearance &&
      listEquals(other.overviewWidgets, overviewWidgets) &&
      other.breakdownChart == breakdownChart &&
      other.breakdownLevel == breakdownLevel &&
      other.chartColours == chartColours &&
      other.savingsPocketID == savingsPocketID;

  @override
  int get hashCode => Object.hash(
    appearance,
    Object.hashAll(overviewWidgets),
    breakdownChart,
    breakdownLevel,
    chartColours,
    savingsPocketID,
  );
}
