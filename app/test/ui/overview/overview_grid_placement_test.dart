import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_grid_placement.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _roomyGridWidth = 1000.0;
const _wideWindowWidth = 1600.0;
const _justBelowDesktopThreshold = 1249.0;
const _desktopThreshold = 1250.0;
const _openThreeColumnMinimumGrid = 680.0;
const _openJustBelowMinimumGrid = 679.0;
const _desktopTwoColumnMinimumGrid = 450.0;
const _desktopJustBelowMinimumGrid = 449.0;
const _gap = 10.0;
const _expectedSpanTwoKinds = {
  OverviewWidgetKind.today,
  OverviewWidgetKind.recentEntries,
  OverviewWidgetKind.spendingOverTime,
};

int _columns({
  ShellLayoutMode mode = ShellLayoutMode.open,
  ShellPagePresentation presentation = ShellPagePresentation.fullPage,
  double windowWidth = _wideWindowWidth,
  double gridWidth = _roomyGridWidth,
}) => overviewColumnCount(
  mode: mode,
  presentation: presentation,
  windowWidth: windowWidth,
  gridWidth: gridWidth,
);

({int column, double top}) _place(List<double> bottoms, int span) =>
    placeOverviewCard(columnBottoms: bottoms, span: span);

List<int> _simulateColumns(List<(int span, double height)> cards, int columns) {
  final bottoms = List<double>.filled(columns, 0);
  final chosen = <int>[];
  for (final (span, height) in cards) {
    final placement = _place(bottoms, span);
    final covered = span < columns ? span : columns;
    bottoms.fillRange(
      placement.column,
      placement.column + covered,
      placement.top + height + _gap,
    );
    chosen.add(placement.column);
  }
  return chosen;
}

void main() {
  group('overviewColumnCount', () {
    test('phone gives one column', () {
      expect(_columns(mode: ShellLayoutMode.phone), 1);
    });

    test('desktop gives two columns below 1250 and three from 1250', () {
      final below = _columns(
        mode: ShellLayoutMode.desktop,
        windowWidth: _justBelowDesktopThreshold,
      );
      final at = _columns(
        mode: ShellLayoutMode.desktop,
        windowWidth: _desktopThreshold,
      );

      expect([below, at], [2, 3]);
    });

    test('open full page gives three columns', () {
      expect(_columns(), 3);
    });

    test('single column presentation gives one column in open and desktop', () {
      final open = _columns(presentation: ShellPagePresentation.singleColumn);
      final desktop = _columns(
        mode: ShellLayoutMode.desktop,
        presentation: ShellPagePresentation.singleColumn,
        windowWidth: _desktopThreshold,
      );

      expect([open, desktop], [1, 1]);
    });

    test('open drops to one column when a column would be under 220', () {
      final atMinimum = _columns(gridWidth: _openThreeColumnMinimumGrid);
      final below = _columns(gridWidth: _openJustBelowMinimumGrid);

      expect([atMinimum, below], [3, 1]);
    });

    test(
      'desktop two columns drop to one when a column would be under 220',
      () {
        final atMinimum = _columns(
          mode: ShellLayoutMode.desktop,
          windowWidth: _justBelowDesktopThreshold,
          gridWidth: _desktopTwoColumnMinimumGrid,
        );
        final below = _columns(
          mode: ShellLayoutMode.desktop,
          windowWidth: _justBelowDesktopThreshold,
          gridWidth: _desktopJustBelowMinimumGrid,
        );

        expect([atMinimum, below], [2, 1]);
      },
    );
  });

  group('overviewColumnSpan', () {
    test('only today, recent entries and spending over time span two', () {
      final wide = OverviewWidgetKind.values
          .where((kind) => overviewColumnSpan(kind) == 2)
          .toSet();
      final narrow = OverviewWidgetKind.values
          .where((kind) => overviewColumnSpan(kind) == 1)
          .toSet();

      expect(wide, _expectedSpanTwoKinds);
      expect(narrow, OverviewWidgetKind.values.toSet()..removeAll(wide));
    });
  });

  group('placeOverviewCard', () {
    test('empty columns put a one-column card at column 0 top 0', () {
      expect(_place([0, 0, 0], 1), (column: 0, top: 0.0));
    });

    test('a one-column card goes to the shortest column', () {
      expect(_place([300, 100, 200], 1), (column: 1, top: 100.0));
    });

    test('a one-column card takes the leftmost of equal columns', () {
      expect(_place([200, 100, 100], 1), (column: 1, top: 100.0));
    });

    test('a two-column card takes the pair with the least waste', () {
      expect(_place([210, 210, 510], 2), (column: 0, top: 210.0));
    });

    test('a two-column card prefers the lower top on equal waste', () {
      expect(_place([300, 100, 200], 2), (column: 1, top: 200.0));
    });

    test('a two-column card takes the leftmost pair on a full tie', () {
      expect(_place([100, 100, 100], 2), (column: 0, top: 100.0));
    });

    test('a span wider than the grid is clamped to the column count', () {
      expect(_place([120], 2), (column: 0, top: 120.0));
    });

    test('a two-column card leaves an unavoidable gap beside tall columns', () {
      expect(_place([100, 400, 100], 2), (column: 0, top: 400.0));
    });
  });

  group('waterfall sequencing', () {
    test('equal-height cards fill the columns left to right in order', () {
      final columns = _simulateColumns([
        (1, 100),
        (1, 100),
        (1, 100),
        (1, 100),
      ], 3);

      expect(columns, [0, 1, 2, 0]);
    });

    test('the next card in stored order goes under the shortest column', () {
      final columns = _simulateColumns([
        (1, 300),
        (1, 100),
        (1, 200),
        (1, 50),
        (1, 50),
      ], 3);

      expect(columns, [0, 1, 2, 1, 1]);
    });

    test('a spanning card sits where it wastes the least space', () {
      final columns = _simulateColumns([
        (1, 200),
        (1, 200),
        (1, 500),
        (2, 100),
      ], 3);

      expect(columns, [0, 1, 2, 0]);
    });
  });
}
