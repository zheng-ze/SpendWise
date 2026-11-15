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

List<OverviewWidgetKind> _order(List<OverviewGridCell> cells) =>
    cells.map((cell) => cell.kind).toList();

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

  group('placeOverviewWidgets', () {
    test('backfills a one-column widget ahead of a spanning widget', () {
      final cells = placeOverviewWidgets([
        OverviewWidgetKind.today,
        OverviewWidgetKind.recentEntries,
        OverviewWidgetKind.comingUp,
      ], columnCount: 3);

      expect(cells, [
        (kind: OverviewWidgetKind.today, row: 0, column: 0, span: 2),
        (kind: OverviewWidgetKind.comingUp, row: 0, column: 2, span: 1),
        (kind: OverviewWidgetKind.recentEntries, row: 1, column: 0, span: 2),
      ]);
    });

    test('two columns give a spanning widget the whole row', () {
      final cells = placeOverviewWidgets([
        OverviewWidgetKind.today,
        OverviewWidgetKind.recentEntries,
      ], columnCount: 2);

      expect(cells, [
        (kind: OverviewWidgetKind.today, row: 0, column: 0, span: 2),
        (kind: OverviewWidgetKind.recentEntries, row: 1, column: 0, span: 2),
      ]);
    });

    test('two columns fill a hole ahead of the spanning widget', () {
      final cells = placeOverviewWidgets([
        OverviewWidgetKind.comingUp,
        OverviewWidgetKind.today,
        OverviewWidgetKind.thisMonth,
      ], columnCount: 2);

      expect(cells, [
        (kind: OverviewWidgetKind.comingUp, row: 0, column: 0, span: 1),
        (kind: OverviewWidgetKind.thisMonth, row: 0, column: 1, span: 1),
        (kind: OverviewWidgetKind.today, row: 1, column: 0, span: 2),
      ]);
    });

    test('hole-filling widgets keep their stored relative order', () {
      final cells = placeOverviewWidgets([
        OverviewWidgetKind.comingUp,
        OverviewWidgetKind.today,
        OverviewWidgetKind.thisMonth,
        OverviewWidgetKind.insights,
      ], columnCount: 2);

      expect(_order(cells), [
        OverviewWidgetKind.comingUp,
        OverviewWidgetKind.thisMonth,
        OverviewWidgetKind.today,
        OverviewWidgetKind.insights,
      ]);
    });

    test('a lone spanning widget leaves the trailing cell empty', () {
      final cells = placeOverviewWidgets([
        OverviewWidgetKind.today,
      ], columnCount: 3);

      expect(cells, [
        (kind: OverviewWidgetKind.today, row: 0, column: 0, span: 2),
      ]);
    });

    test('one column keeps stored order with span one', () {
      final kinds = [
        OverviewWidgetKind.today,
        OverviewWidgetKind.comingUp,
        OverviewWidgetKind.recentEntries,
      ];

      final cells = placeOverviewWidgets(kinds, columnCount: 1);

      expect(cells, [
        (kind: OverviewWidgetKind.today, row: 0, column: 0, span: 1),
        (kind: OverviewWidgetKind.comingUp, row: 1, column: 0, span: 1),
        (kind: OverviewWidgetKind.recentEntries, row: 2, column: 0, span: 1),
      ]);
    });

    test('no kinds gives no cells', () {
      expect(placeOverviewWidgets(const [], columnCount: 3), isEmpty);
    });
  });
}
