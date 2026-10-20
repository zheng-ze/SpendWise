import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_today_section.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import 'overview_fixture.dart';
import '../../support/ui_test_timeout.dart';

const _phoneSize = Size(320, 760);
const _openSize = Size(960, 720);
const _testDevicePixelRatio = 1.0;

void _ignoreHistory() {}
const _geometryTolerance = 0.01;
const _minimumTallRowHeight = 200.0;
const _narrowOpenSize = Size(600, 480);
const _largeTextScales = [1.3, 2.0];
const _pagePaddingWidth = 28.0;
const _gridSwitchPageWidth =
    overviewGridMinimumColumnWidth * overviewGridColumnCount +
    overviewTrayGap * overviewGridGapCount +
    _pagePaddingWidth;

Future<ProviderContainer> _pumpOverview(
  WidgetTester tester,
  LedgerState state, {
  required Brightness brightness,
  ComputeRunner runner = syncComputeRunner,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.reset);
  final ledger = Ledger(state: state);
  final container = overviewContainer(ledger, runner: runner);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSpendWiseTheme(brightness),
        home: OverviewFlow(onHistorySelected: _ignoreHistory),
      ),
    ),
  );
  await tester.runAsync(() => settleAnalysis(container, ledger));
  await tester.pumpAndSettle();
  return container;
}

Finder _inTray(String title, String text) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Tray)),
  matching: find.text(text),
);

class _LoadingOverviewNotifier extends OverviewNotifier {
  @override
  Future<OverviewViewState> build() async => OverviewViewState(
    day: fixtureToday,
    today: null,
    recent: null,
    upcoming: null,
  );
}

Color? _textColor(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.color;

Future<ProviderContainer> _pumpOpenOverview(
  WidgetTester tester,
  LedgerState state, {
  required Brightness brightness,
  bool addPresented = false,
  ShellDetail? detail,
  OverviewViewState? viewState,
  ComputeRunner runner = syncComputeRunner,
  Size size = _openSize,
  double textScale = 1,
  ProviderContainer? existing,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final ledger = Ledger(state: state);
  final container =
      existing ??
      (viewState == null
          ? overviewContainer(ledger, runner: runner)
          : _fixedContainer(viewState));
  final overview = detail == null
      ? OverviewFlow(onHistorySelected: _ignoreHistory)
      : _HostedOverviewScreen(detail: detail);
  await tester.pumpWidget(
    _OpenApp(
      container: container,
      brightness: brightness,
      addPresented: addPresented,
      pageWidth: size.width,
      child: overview,
    ),
  );
  if (existing == null && viewState == null) {
    await tester.runAsync(() => settleAnalysis(container, ledger));
  }
  await tester.pumpAndSettle();
  return container;
}

ProviderContainer _fixedContainer(OverviewViewState viewState) {
  final container = ProviderContainer(
    overrides: [
      overviewViewModelProvider.overrideWith(
        () => _FixedOverviewNotifier(viewState),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _OpenApp extends StatelessWidget {
  const _OpenApp({
    required this.container,
    required this.brightness,
    required this.addPresented,
    required this.pageWidth,
    required this.child,
  });

  final ProviderContainer container;
  final Brightness brightness;
  final bool addPresented;
  final double pageWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shell = ShellPaneScope(
      mode: ShellLayoutMode.open,
      safeBodyWidth: pageWidth,
      addPresented: addPresented,
      child: child,
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildSpendWiseTheme(brightness), home: shell),
    );
  }
}

class _FixedOverviewNotifier extends OverviewNotifier {
  _FixedOverviewNotifier(this.viewState);

  final OverviewViewState viewState;

  @override
  Future<OverviewViewState> build() async => viewState;
}

class _HostedOverviewScreen extends StatelessWidget {
  const _HostedOverviewScreen({this.detail});

  final ShellDetail? detail;

  @override
  Widget build(BuildContext context) => ShellPaneHost(
    detail: detail,
    pageBuilder: (context, presentation) => OverviewScreen(
      layoutMode: ShellLayoutMode.open,
      presentation: presentation,
    ),
  );
}

typedef _Rects = ({Rect today, Rect recent, Rect coming});

_Rects _rects(WidgetTester tester) => (
  today: tester.getRect(find.byType(TodayTray)),
  recent: tester.getRect(_trayFinder('Recent entries')),
  coming: tester.getRect(_trayFinder('Coming up')),
);

Finder _trayFinder(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(Tray)).first;

void _expectGrid(WidgetTester tester, double pageWidth) {
  final rects = _rects(tester);
  const gaps = overviewTrayGap * overviewGridGapCount;
  final columnWidth =
      (pageWidth - _pagePaddingWidth - gaps) / overviewGridColumnCount;
  final spanWidth = columnWidth * overviewGridSpanColumnCount + overviewTrayGap;

  expect(rects.today.width, closeTo(spanWidth, _geometryTolerance));
  expect(rects.recent.width, closeTo(spanWidth, _geometryTolerance));
  expect(rects.coming.width, closeTo(columnWidth, _geometryTolerance));
  expect(rects.recent.left, rects.today.left);
  expect(rects.recent.top, rects.coming.top);
  expect(rects.coming.left, rects.recent.right + overviewTrayGap);
  expect(rects.recent.height, rects.coming.height);
  expect(rects.recent.top, greaterThan(rects.today.bottom));
}

void _expectSingleColumn(WidgetTester tester, double pageWidth) {
  final rects = _rects(tester);
  final width = pageWidth - _pagePaddingWidth;

  expect(rects.today.width, closeTo(width, _geometryTolerance));
  expect(rects.recent.width, closeTo(width, _geometryTolerance));
  expect(rects.coming.width, closeTo(width, _geometryTolerance));
  expect(rects.today.bottom, lessThan(rects.recent.top));
  expect(rects.recent.bottom, lessThan(rects.coming.top));
}

OverviewViewState _overviewState({
  List<OverviewEntryRow>? recent = const [],
  List<OverviewUpcomingRow>? upcoming = const [],
}) => OverviewViewState(
  day: fixtureToday,
  today: null,
  recent: recent,
  upcoming: upcoming,
);

OverviewUpcomingRow _upcomingRow(int index) => OverviewUpcomingRow(
  day: '${index + 1}',
  month: 'Oct',
  title: 'Upcoming entry $index',
  caption: 'Checking',
  amount: Decimal.parse('1.00'),
  amountKind: AmountKind.expense,
);

OverviewEntryRow _longRecentRow() => OverviewEntryRow(
  title: _repeatedText('Recent entry ', 24),
  caption: _repeatedText('Long account and category caption ', 12),
  symbolName: 'receipt',
  color: Colors.blue,
  amount: Decimal.parse('1.00'),
  amountKind: AmountKind.expense,
);

String _repeatedText(String value, int count) =>
    List<String>.filled(count, value).join();

Widget _detailBody(BuildContext context) => const SizedBox.expand();

void _closeDetail() {}

void main() {
  for (final brightness in Brightness.values) {
    final colors = brightness == Brightness.dark
        ? SpendWiseColors.dark
        : SpendWiseColors.light;

    group('ov-default in ${brightness.name}', () {
      testWidgets('shows the header, Today, Recent entries and Coming up', (
        tester,
      ) async {
        await _pumpOverview(tester, defaultState(), brightness: brightness);

        expect(find.text('Saturday, 3 October'), findsOneWidget);
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Today / 3 October'), findsOneWidget);
        expect(find.text('S\$45.70'), findsOneWidget);
        expect(find.text('Daily guide: about S\$39'), findsOneWidget);
        expect(find.text('From your S\$1,200 monthly cap.'), findsOneWidget);
        expect(find.text('Recent entries'), findsOneWidget);
        expect(find.text('View History'), findsOneWidget);
        expect(find.text('Coming up'), findsOneWidget);
        expect(find.text('Next 6 weeks'), findsOneWidget);
        expect(find.text('Edit Overview'), findsNothing);
        final order = [
          'Today / 3 October',
          'Recent entries',
          'Coming up',
        ].map((label) => tester.getTopLeft(find.text(label)).dy).toList();
        expect(order, [...order]..sort());
      }, timeout: uiTestTimeout);

      testWidgets('renders four recent rows with signed, styled amounts', (
        tester,
      ) async {
        await _pumpOverview(tester, defaultState(), brightness: brightness);

        for (final title in [
          'Snack',
          'Shop run',
          'To savings',
          'Monthly pay',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.text('Yesterday bite'), findsNothing);
        expect(find.text('Today / Salary / Checking'), findsOneWidget);
        expect(
          find.text('Today / Transfer / Checking > Savings'),
          findsOneWidget,
        );
        final income = _inTray('Recent entries', '+3,200.00');
        final moved = _inTray('Recent entries', '500.00');
        final spent = _inTray('Recent entries', '-42.50');
        expect(income, findsOneWidget);
        expect(moved, findsOneWidget);
        expect(spent, findsOneWidget);
        expect(_inTray('Recent entries', '-3.20'), findsOneWidget);
        expect(_textColor(tester, income), colors.income);
        expect(_textColor(tester, spent), colors.expense);
        expect(_textColor(tester, moved), colors.text);
      }, timeout: uiTestTimeout);

      testWidgets('renders the upcoming rows in date order', (tester) async {
        await _pumpOverview(tester, defaultState(), brightness: brightness);

        final titles = [
          'Amex Card statement closes',
          'Streaming',
          'Wages',
          'Rent',
        ];
        final tops = [
          for (final title in titles) tester.getTopLeft(find.text(title)).dy,
        ];
        expect(tops, [...tops]..sort());
        expect(find.text('This cycle so far: S\$45.70'), findsOneWidget);
        expect(find.text('Plan / Amex Card'), findsOneWidget);
        expect(find.text('Plan / Checking'), findsOneWidget);
        expect(find.text('Dated ahead / Checking'), findsOneWidget);
        expect(_inTray('Coming up', '-19.98'), findsOneWidget);
        expect(_inTray('Coming up', '+3,200.00'), findsOneWidget);
        expect(_inTray('Coming up', '-1,200.00'), findsOneWidget);
        expect(find.text('Oct'), findsNWidgets(3));
        expect(find.text('Nov'), findsOneWidget);
      }, timeout: uiTestTimeout);

      testWidgets('asks for a monthly cap when no unscoped budget exists', (
        tester,
      ) async {
        final state = emptyState();
        state.addEntry(
          entry(
            1,
            '-5.00',
            fixtureToday,
            name: 'Lunch',
            categoryID: groceriesID,
          ),
        );
        await _pumpOverview(tester, state, brightness: brightness);

        expect(
          find.text('Set a monthly cap to see a daily guide.'),
          findsOneWidget,
        );
        expect(find.text('Set a monthly cap'), findsOneWidget);
        expect(find.textContaining('Daily guide'), findsNothing);
      }, timeout: uiTestTimeout);

      testWidgets('shows an error with Retry when Today fails', (tester) async {
        var failing = true;
        await _pumpOverview(
          tester,
          defaultState(),
          brightness: brightness,
          runner: (state) => failing
              ? Future.error(StateError('boom'))
              : syncComputeRunner(state),
        );

        expect(find.text("Couldn't load today's spending"), findsOneWidget);
        expect(find.text('S\$45.70'), findsNothing);
        expect(find.text('Recent entries'), findsOneWidget);

        failing = false;
        await tester.tap(find.text('Retry'));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pumpAndSettle();

        expect(find.text("Couldn't load today's spending"), findsNothing);
        expect(find.text('S\$45.70'), findsOneWidget);
      }, timeout: uiTestTimeout);

      testWidgets('is never empty on a fresh install', (tester) async {
        await _pumpOverview(tester, LedgerState(), brightness: brightness);

        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Nothing recorded today'), findsOneWidget);
        expect(find.text('Recent entries'), findsOneWidget);
        expect(find.text('Your entries will appear here.'), findsOneWidget);
        expect(find.text('Coming up'), findsOneWidget);
        expect(
          find.text('No known dates in the next six weeks.'),
          findsOneWidget,
        );
      }, timeout: uiTestTimeout);

      testWidgets('View History requests the history page', (tester) async {
        tester.view.physicalSize = _phoneSize;
        tester.view.devicePixelRatio = _testDevicePixelRatio;
        addTearDown(tester.view.reset);
        final ledger = Ledger(state: defaultState());
        final container = overviewContainer(ledger);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildSpendWiseTheme(brightness),
              home: const OverviewScreen(),
            ),
          ),
        );
        await tester.runAsync(() => settleAnalysis(container, ledger));
        await tester.pumpAndSettle();

        final action = find.widgetWithText(TextButton, 'View History');
        expect(action, findsOneWidget);
        expect(tester.widget<TextButton>(action).onPressed, isNotNull);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(tester.getSemantics(action).flagsCollection.isButton, isTrue);

        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();

        expect(
          container.read(overviewViewModelProvider).requireValue.step,
          isA<OverviewHistoryRequested>(),
        );
      }, timeout: uiTestTimeout);

      testWidgets('View History is shown when recent entries are empty', (
        tester,
      ) async {
        await _pumpOverview(tester, LedgerState(), brightness: brightness);

        expect(find.text('Your entries will appear here.'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'View History'), findsOneWidget);
      }, timeout: uiTestTimeout);

      testWidgets('View History is shown while the recent section loads', (
        tester,
      ) async {
        tester.view.physicalSize = _phoneSize;
        tester.view.devicePixelRatio = _testDevicePixelRatio;
        addTearDown(tester.view.reset);
        final container = ProviderContainer(
          overrides: [
            overviewViewModelProvider.overrideWith(
              () => _LoadingOverviewNotifier(),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildSpendWiseTheme(brightness),
              home: OverviewFlow(onHistorySelected: _ignoreHistory),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(LoadingSkeleton), findsWidgets);
        expect(find.widgetWithText(TextButton, 'View History'), findsOneWidget);
      }, timeout: uiTestTimeout);

      testWidgets('open Overview uses the sparse three-column grid', (
        tester,
      ) async {
        await _pumpOpenOverview(tester, defaultState(), brightness: brightness);

        _expectGrid(tester, _openSize.width);
      }, timeout: uiTestTimeout);

      testWidgets(
        'Add or detail uses one column and closing restores the grid',
        (tester) async {
          const detail = ShellDetail(
            id: 'test-detail',
            title: 'Detail',
            bodyBuilder: _detailBody,
            onClose: _closeDetail,
          );
          final container = await _pumpOpenOverview(
            tester,
            defaultState(),
            brightness: brightness,
            addPresented: true,
          );
          final pageWidth = _openSize.width / 2;
          _expectSingleColumn(tester, pageWidth);

          await _pumpOpenOverview(
            tester,
            defaultState(),
            brightness: brightness,
            existing: container,
          );
          _expectGrid(tester, _openSize.width);

          await _pumpOpenOverview(
            tester,
            defaultState(),
            brightness: brightness,
            detail: detail,
            existing: container,
          );
          _expectSingleColumn(tester, pageWidth);
        },
        timeout: uiTestTimeout,
      );

      testWidgets('the grid switches to one column at the minimum width', (
        tester,
      ) async {
        const narrowerThanGrid = Size(_gridSwitchPageWidth - 1, 720);
        const atGrid = Size(_gridSwitchPageWidth, 720);

        await _pumpOpenOverview(
          tester,
          defaultState(),
          brightness: brightness,
          size: narrowerThanGrid,
        );
        _expectSingleColumn(tester, narrowerThanGrid.width);

        await _pumpOpenOverview(
          tester,
          defaultState(),
          brightness: brightness,
          size: atGrid,
        );
        _expectGrid(tester, atGrid.width);
      }, timeout: uiTestTimeout);

      testWidgets('open Overview stays one column without overflow at 600', (
        tester,
      ) async {
        for (final textScale in [1.0, 2.0]) {
          await _pumpOpenOverview(
            tester,
            defaultState(),
            brightness: brightness,
            size: _narrowOpenSize,
            textScale: textScale,
          );

          _expectSingleColumn(tester, _narrowOpenSize.width);
          expect(tester.takeException(), isNull);
        }
      }, timeout: uiTestTimeout);

      testWidgets('open grid has no overflow with large text', (tester) async {
        final state = _overviewState(
          recent: [_longRecentRow()],
          upcoming: List.generate(4, _upcomingRow),
        );
        for (final textScale in _largeTextScales) {
          await _pumpOpenOverview(
            tester,
            emptyState(),
            brightness: brightness,
            viewState: state,
            textScale: textScale,
          );

          _expectGrid(tester, _openSize.width);
          expect(tester.takeException(), isNull);
        }
      }, timeout: uiTestTimeout);

      testWidgets('row two stretches when Coming up is taller', (tester) async {
        final state = _overviewState(upcoming: List.generate(8, _upcomingRow));
        await _pumpOpenOverview(
          tester,
          emptyState(),
          brightness: brightness,
          viewState: state,
        );

        final rects = _rects(tester);

        expect(rects.recent.height, rects.coming.height);
        expect(rects.coming.height, greaterThan(_minimumTallRowHeight));
      }, timeout: uiTestTimeout);

      testWidgets('row two stretches when Recent entries is taller', (
        tester,
      ) async {
        final state = _overviewState(recent: [_longRecentRow()]);
        await _pumpOpenOverview(
          tester,
          emptyState(),
          brightness: brightness,
          viewState: state,
        );

        final rects = _rects(tester);

        expect(rects.recent.height, rects.coming.height);
        expect(rects.recent.height, greaterThan(_minimumTallRowHeight));
      }, timeout: uiTestTimeout);

      testWidgets('open Overview preserves empty and loading sections', (
        tester,
      ) async {
        await _pumpOpenOverview(tester, LedgerState(), brightness: brightness);

        expect(find.text('Nothing recorded today'), findsOneWidget);
        expect(find.text('Your entries will appear here.'), findsOneWidget);
        expect(
          find.text('No known dates in the next six weeks.'),
          findsOneWidget,
        );

        final loading = _overviewState(recent: null, upcoming: null);
        await _pumpOpenOverview(
          tester,
          emptyState(),
          brightness: brightness,
          viewState: loading,
        );

        expect(find.byType(LoadingSkeleton), findsNWidgets(3));
        expect(find.widgetWithText(TextButton, 'View History'), findsOneWidget);
      }, timeout: uiTestTimeout);

      testWidgets('open Today error keeps Retry behavior', (tester) async {
        var failing = true;
        await _pumpOpenOverview(
          tester,
          defaultState(),
          brightness: brightness,
          runner: (state) => failing
              ? Future.error(StateError('boom'))
              : syncComputeRunner(state),
        );

        expect(find.text("Couldn't load today's spending"), findsOneWidget);
        expect(find.text('Recent entries'), findsOneWidget);
        expect(find.text('Coming up'), findsOneWidget);

        failing = false;
        await tester.tap(find.text('Retry'));
        await tester.runAsync(() => pumpEventQueue());
        await tester.pumpAndSettle();

        expect(find.text("Couldn't load today's spending"), findsNothing);
        expect(find.text('S\$45.70'), findsOneWidget);
      }, timeout: uiTestTimeout);
    });
  }
}
