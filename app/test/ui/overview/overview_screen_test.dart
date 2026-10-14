import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_today_section.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import 'overview_fixture.dart';

const _phoneSize = Size(320, 760);
const _openWidth = 960.0;
const _openSize = Size(_openWidth, 720);
const _testDevicePixelRatio = 1.0;
const _overviewHorizontalInsets = 28.0;
const _openGridGap = 10.0;
const _openGridGapCount = 2;
const _openGridColumnCount = 3;
const _openGridSpanColumnCount = 2;
const _geometryTolerance = 0.01;
const _minimumTallRowHeight = 200.0;
const _openThresholdSize = Size(600, 480);
const _thresholdTextScales = [1.0, 2.0];
const _phoneThresholdSizes = [Size(599, 480), Size(600, 479)];

Future<ProviderContainer> _pumpOverview(
  WidgetTester tester,
  LedgerState state, {
  required Brightness brightness,
  ComputeRunner runner = syncComputeRunner,
  Size size = _phoneSize,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.reset);
  final ledger = Ledger(state: state);
  final container = overviewContainer(ledger, runner: runner);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSpendWiseTheme(brightness),
        home: const OverviewFlow(),
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
}) async {
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.reset);
  final ledger = Ledger(state: state);
  final container = viewState == null
      ? overviewContainer(ledger, runner: runner)
      : ProviderContainer(
          overrides: [
            overviewViewModelProvider.overrideWith(
              () => _FixedOverviewNotifier(viewState),
            ),
          ],
        );
  if (viewState != null) addTearDown(container.dispose);
  final overview = detail == null
      ? const OverviewFlow()
      : _HostedOverviewScreen(detail: detail);
  await tester.pumpWidget(
    _OpenApp(
      container: container,
      brightness: brightness,
      addPresented: addPresented,
      child: overview,
    ),
  );
  if (viewState == null) {
    await tester.runAsync(() => settleAnalysis(container, ledger));
  }
  await tester.pumpAndSettle();
  return container;
}

class _OpenApp extends StatelessWidget {
  const _OpenApp({
    required this.container,
    required this.brightness,
    required this.addPresented,
    required this.child,
  });

  final ProviderContainer container;
  final Brightness brightness;
  final bool addPresented;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shell = ShellPaneScope(
      mode: ShellLayoutMode.open,
      safeBodyWidth: _openWidth,
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

Rect _todayRect(WidgetTester tester) => tester.getRect(find.byType(TodayTray));

Rect _trayRect(WidgetTester tester, String title) {
  final tray = find.ancestor(of: find.text(title), matching: find.byType(Tray));
  return tester.getRect(tray.first);
}

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
      });

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
      });

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
      });

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
      });

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
      });

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
      });

      testWidgets('phone threshold sizes wrap without overflow', (
        tester,
      ) async {
        for (final size in _phoneThresholdSizes) {
          await _pumpOverview(
            tester,
            defaultState(),
            brightness: brightness,
            size: size,
          );

          expect(find.text('Today / 3 October'), findsOneWidget);
          expect(find.text('Recent entries'), findsOneWidget);
          expect(find.text('Coming up'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });

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
      });

      testWidgets('View History is shown when recent entries are empty', (
        tester,
      ) async {
        await _pumpOverview(tester, LedgerState(), brightness: brightness);

        expect(find.text('Your entries will appear here.'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'View History'), findsOneWidget);
      });

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
              home: const OverviewFlow(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(LoadingSkeleton), findsWidgets);
        expect(find.widgetWithText(TextButton, 'View History'), findsOneWidget);
      });

      testWidgets('open Overview uses the sparse three-column grid', (
        tester,
      ) async {
        await _pumpOpenOverview(tester, defaultState(), brightness: brightness);

        final today = _todayRect(tester);
        final recent = _trayRect(tester, 'Recent entries');
        final coming = _trayRect(tester, 'Coming up');
        const contentWidth = _openWidth - _overviewHorizontalInsets;
        const gridColumnWidth =
            (contentWidth - _openGridGap * _openGridGapCount) /
            _openGridColumnCount;

        expect(
          today.width,
          closeTo(
            gridColumnWidth * _openGridSpanColumnCount + _openGridGap,
            _geometryTolerance,
          ),
        );
        expect(recent.width, today.width);
        expect(coming.width, closeTo(gridColumnWidth, _geometryTolerance));
        expect(today.left, recent.left);
        expect(recent.top, coming.top);
        expect(recent.left + recent.width + _openGridGap, coming.left);
        expect(today.right + _openGridGap, coming.left);
        expect(coming.top, greaterThan(today.top));
        expect(today.top, lessThan(recent.top));
        expect(recent.height, coming.height);
        expect(find.byType(Tray), findsNWidgets(2));
      });

      testWidgets('open Overview uses one column while Add is presented', (
        tester,
      ) async {
        await _pumpOpenOverview(
          tester,
          defaultState(),
          brightness: brightness,
          addPresented: true,
        );

        final today = _todayRect(tester);
        final recent = _trayRect(tester, 'Recent entries');
        final coming = _trayRect(tester, 'Coming up');

        expect(today.width, recent.width);
        expect(recent.width, coming.width);
        expect(today.top, lessThan(recent.top));
        expect(recent.top, lessThan(coming.top));
      });

      testWidgets('closing Add restores the open Overview grid', (
        tester,
      ) async {
        tester.view.physicalSize = _openSize;
        tester.view.devicePixelRatio = _testDevicePixelRatio;
        addTearDown(tester.view.reset);
        final ledger = Ledger(state: defaultState());
        final container = overviewContainer(ledger);
        Future<void> pumpShell({required bool addPresented}) =>
            tester.pumpWidget(
              _OpenApp(
                container: container,
                brightness: brightness,
                addPresented: addPresented,
                child: const _HostedOverviewScreen(),
              ),
            );
        await pumpShell(addPresented: true);
        await tester.runAsync(() => settleAnalysis(container, ledger));
        await tester.pumpAndSettle();

        final singleColumnToday = _todayRect(tester);
        final singleColumnRecent = _trayRect(tester, 'Recent entries');
        final singleColumnComing = _trayRect(tester, 'Coming up');
        expect(singleColumnToday.width, singleColumnRecent.width);
        expect(singleColumnRecent.width, singleColumnComing.width);

        await pumpShell(addPresented: false);
        await tester.pumpAndSettle();

        final gridToday = _todayRect(tester);
        final gridRecent = _trayRect(tester, 'Recent entries');
        final gridComing = _trayRect(tester, 'Coming up');
        expect(gridToday.width, gridRecent.width);
        expect(gridComing.width, lessThan(gridToday.width));
        expect(gridRecent.top, gridComing.top);
      });

      testWidgets('open Overview uses one column beside a detail pane', (
        tester,
      ) async {
        await _pumpOpenOverview(
          tester,
          defaultState(),
          brightness: brightness,
          detail: const ShellDetail(
            id: 'test-detail',
            title: 'Detail',
            bodyBuilder: _detailBody,
            onClose: _closeDetail,
          ),
        );

        final today = _todayRect(tester);
        final recent = _trayRect(tester, 'Recent entries');
        final coming = _trayRect(tester, 'Coming up');

        expect(today.width, recent.width);
        expect(recent.width, coming.width);
        expect(today.top, lessThan(recent.top));
        expect(recent.top, lessThan(coming.top));
      });

      testWidgets('row two stretches when Coming up is taller', (tester) async {
        final state = _overviewState(upcoming: List.generate(8, _upcomingRow));
        await _pumpOpenOverview(
          tester,
          emptyState(),
          brightness: brightness,
          viewState: state,
        );

        final recent = _trayRect(tester, 'Recent entries');
        final coming = _trayRect(tester, 'Coming up');

        expect(recent.height, coming.height);
        expect(coming.height, greaterThan(_minimumTallRowHeight));
      });

      testWidgets('row two stretches when Recent entries is taller', (
        tester,
      ) async {
        final state = _overviewState(
          recent: [
            OverviewEntryRow(
              title: _repeatedText('Recent entry ', 24),
              caption: _repeatedText('Long account and category caption ', 12),
              symbolName: 'receipt',
              color: Colors.blue,
              amount: Decimal.parse('1.00'),
              amountKind: AmountKind.expense,
            ),
          ],
        );
        await _pumpOpenOverview(
          tester,
          emptyState(),
          brightness: brightness,
          viewState: state,
        );

        final recent = _trayRect(tester, 'Recent entries');
        final coming = _trayRect(tester, 'Coming up');

        expect(recent.height, coming.height);
        expect(recent.height, greaterThan(_minimumTallRowHeight));
      });

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
      });

      testWidgets('open Overview has no overflow at the threshold', (
        tester,
      ) async {
        for (final textScale in _thresholdTextScales) {
          await _pumpOpenOverview(
            tester,
            defaultState(),
            brightness: brightness,
            size: _openThresholdSize,
            textScale: textScale,
          );

          expect(tester.takeException(), isNull);
        }
      });

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
      });
    });
  }
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

String _repeatedText(String value, int count) =>
    List<String>.filled(count, value).join();

Widget _detailBody(BuildContext context) => const SizedBox.expand();

void _closeDetail() {}
