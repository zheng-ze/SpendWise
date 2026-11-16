import 'dart:math' as math;

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _placementTolerance = 1e-10;
const _emptyColumnBottom = 0.0;
const _emptyGridHeight = 0.0;

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

({int column, double top}) placeOverviewCard({
  required List<double> columnBottoms,
  required int span,
}) {
  assert(columnBottoms.isNotEmpty);
  assert(span >= 1);
  final clampedSpan = math.min(span, columnBottoms.length);
  var bestColumn = 0;
  var bestTop = double.infinity;
  var bestWaste = double.infinity;
  for (var column = 0; column <= columnBottoms.length - clampedSpan; column++) {
    final covered = columnBottoms.sublist(column, column + clampedSpan);
    final top = covered.reduce(math.max);
    final waste = covered.fold(0.0, (sum, bottom) => sum + top - bottom);
    final isLessWaste = waste < bestWaste - _placementTolerance;
    final isTieWithLowerTop =
        (waste - bestWaste).abs() <= _placementTolerance &&
        top < bestTop - _placementTolerance;
    if (isLessWaste || isTieWithLowerTop) {
      bestColumn = column;
      bestTop = top;
      bestWaste = waste;
    }
  }
  return (column: bestColumn, top: bestTop);
}

class OverviewWaterfallColumns {
  OverviewWaterfallColumns({required int columnCount, required this.gap})
    : _bottoms = List<double>.filled(columnCount, _emptyColumnBottom);

  final double gap;
  final List<double> _bottoms;
  var _isEmpty = true;

  ({int column, double top}) place({
    required int span,
    required double height,
  }) {
    final clampedSpan = math.min(span, _bottoms.length);
    final placement = placeOverviewCard(
      columnBottoms: _bottoms,
      span: clampedSpan,
    );
    final bottom = placement.top + height + gap;
    _bottoms.fillRange(
      placement.column,
      placement.column + clampedSpan,
      bottom,
    );
    _isEmpty = false;
    return placement;
  }

  double get height =>
      _isEmpty ? _emptyGridHeight : _bottoms.reduce(math.max) - gap;
}
