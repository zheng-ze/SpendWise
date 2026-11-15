import 'dart:math' as math;

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

typedef OverviewGridCell = ({
  OverviewWidgetKind kind,
  int row,
  int column,
  int span,
});

int overviewColumnCount({
  required ShellLayoutMode mode,
  required ShellPagePresentation presentation,
  required double windowWidth,
  required double gridWidth,
}) {
  if (mode == ShellLayoutMode.phone ||
      presentation == ShellPagePresentation.singleColumn) {
    return overviewSingleColumnCount;
  }
  final isWideDesktop =
      mode == ShellLayoutMode.open ||
      windowWidth >= overviewDesktopWideWindowWidth;
  final desired = isWideDesktop
      ? overviewWideColumnCount
      : overviewDesktopColumnCount;
  final gaps = overviewTrayGap * (desired - 1);
  final columnWidth = (gridWidth - gaps) / desired;
  if (columnWidth < overviewMinimumColumnWidth) {
    return overviewSingleColumnCount;
  }
  return desired;
}

int overviewColumnSpan(OverviewWidgetKind kind) => switch (kind) {
  OverviewWidgetKind.today ||
  OverviewWidgetKind.recentEntries ||
  OverviewWidgetKind.spendingOverTime => overviewWideSpan,
  OverviewWidgetKind.thisMonth ||
  OverviewWidgetKind.topCategories ||
  OverviewWidgetKind.cardStatement ||
  OverviewWidgetKind.comingUp ||
  OverviewWidgetKind.accountBalances ||
  OverviewWidgetKind.savingsPocket ||
  OverviewWidgetKind.budgetWatch ||
  OverviewWidgetKind.insights ||
  OverviewWidgetKind.weekSoFar => overviewNarrowSpan,
};

List<OverviewGridCell> placeOverviewWidgets(
  List<OverviewWidgetKind> kinds, {
  required int columnCount,
}) {
  assert(columnCount >= 1);
  final filled = <int>[];
  final cells = <OverviewGridCell>[];
  for (final kind in kinds) {
    final span = math.min(overviewColumnSpan(kind), columnCount);
    var row = filled.indexWhere((used) => columnCount - used >= span);
    if (row == -1) {
      filled.add(0);
      row = filled.length - 1;
    }
    cells.add((kind: kind, row: row, column: filled[row], span: span));
    filled[row] += span;
  }
  cells.sort((a, b) {
    final byRow = a.row.compareTo(b.row);
    return byRow != 0 ? byRow : a.column.compareTo(b.column);
  });
  return cells;
}
