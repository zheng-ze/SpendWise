import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/boot_chrome.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/in_memory_ledger_store.dart';
import 'overview_fixture.dart';

const _phoneSize = Size(400, 800);
const _openSize = Size(960, 720);
const _desktopSize = Size(1200, 900);
const _testDevicePixelRatio = 1.0;
final _responsiveWindowSizeProvider = StateProvider<Size>((ref) => _phoneSize);

Future<ProviderContainer> _pumpOverviewFlow(
  WidgetTester tester, {
  WidgetBuilder? historyRouteBuilder,
  VoidCallback? onHistorySelected,
  bool requestBeforeMount = false,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _testDevicePixelRatio;
  addTearDown(tester.view.reset);
  final ledger = Ledger(state: defaultState());
  final container = overviewContainer(ledger);
  if (requestBeforeMount) {
    container.listen(overviewViewModelProvider, (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.runAsync(() => settleAnalysis(container, ledger));
    await tester.pumpAndSettle();
    container.read(overviewViewModelProvider.notifier).requestHistory();
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: OverviewFlow(
          historyRouteBuilder: historyRouteBuilder,
          onHistorySelected: onHistorySelected,
        ),
      ),
    ),
  );
  if (!requestBeforeMount) {
    await tester.runAsync(() => settleAnalysis(container, ledger));
  }
  await tester.pumpAndSettle();
  return container;
}

WidgetBuilder _phoneHistoryBuilder() =>
    (routeContext) => TransactionsFlow(
      backLabel: 'Overview',
      onEnded: () => Navigator.of(routeContext).pop(),
    );

Future<void> _requestHistory(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(overviewViewModelProvider.notifier).requestHistory();
  await tester.pumpAndSettle();
}

void main() {
  group('phone history route', () {
    testWidgets('pushes one unscoped history flow and clears the step', (
      tester,
    ) async {
      final container = await _pumpOverviewFlow(
        tester,
        historyRouteBuilder: _phoneHistoryBuilder(),
      );
      expect(find.byType(TransactionsFlow), findsNothing);

      await _requestHistory(tester, container);

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.byType(OverviewScreen, skipOffstage: false), findsOneWidget);
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });

    testWidgets('duplicate requests open only one route', (tester) async {
      final container = await _pumpOverviewFlow(
        tester,
        historyRouteBuilder: _phoneHistoryBuilder(),
      );

      await _requestHistory(tester, container);
      await _requestHistory(tester, container);

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });

    testWidgets('back returns to the retained overview and allows reopening', (
      tester,
    ) async {
      final container = await _pumpOverviewFlow(
        tester,
        historyRouteBuilder: _phoneHistoryBuilder(),
      );
      await _requestHistory(tester, container);
      final historyState = tester.state(find.byType(TransactionsFlow));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsFlow), findsNothing);
      expect(find.text('Recent entries'), findsOneWidget);

      await _requestHistory(tester, container);

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(
        tester.state(find.byType(TransactionsFlow)),
        isNot(same(historyState)),
      );
    });

    testWidgets('system Back returns to Overview and allows reopening', (
      tester,
    ) async {
      final container = await _pumpOverviewFlow(
        tester,
        historyRouteBuilder: _phoneHistoryBuilder(),
      );
      await _requestHistory(tester, container);
      final historyState = tester.state(find.byType(TransactionsFlow));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsFlow), findsNothing);
      expect(find.text('Recent entries'), findsOneWidget);

      await _requestHistory(tester, container);

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(
        tester.state(find.byType(TransactionsFlow)),
        isNot(same(historyState)),
      );
    });

    testWidgets('a request before mount is picked up once mounted', (
      tester,
    ) async {
      final container = await _pumpOverviewFlow(
        tester,
        historyRouteBuilder: _phoneHistoryBuilder(),
        requestBeforeMount: true,
      );

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });

    testWidgets('resizing keeps the pushed route and its flow', (tester) async {
      final container = await _pumpOverviewFlow(
        tester,
        historyRouteBuilder: _phoneHistoryBuilder(),
      );
      await _requestHistory(tester, container);
      final historyState = tester.state(find.byType(TransactionsFlow));

      tester.view.physicalSize = const Size(800, 400);
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(tester.state(find.byType(TransactionsFlow)), same(historyState));
    });

    testWidgets('the Overview semantics action returns and allows reopening', (
      tester,
    ) async {
      final container = await _pumpOverviewFlow(
        tester,
        historyRouteBuilder: _phoneHistoryBuilder(),
      );
      await _requestHistory(tester, container);

      final semantics = tester.ensureSemantics();
      try {
        final backControl = find.descendant(
          of: find.byType(AppBar),
          matching: find.bySemanticsLabel('Overview'),
        );
        expect(backControl, findsOneWidget);
        final node = tester.getSemantics(backControl);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();

        expect(find.byType(TransactionsFlow), findsNothing);
        expect(find.text('Recent entries'), findsOneWidget);

        await _requestHistory(tester, container);

        expect(find.byType(TransactionsFlow), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  });

  group('desktop history selection', () {
    testWidgets('selects history without pushing a route', (tester) async {
      var selected = false;
      final container = await _pumpOverviewFlow(
        tester,
        onHistorySelected: () => selected = true,
      );

      await _requestHistory(tester, container);

      expect(selected, isTrue);
      expect(find.byType(TransactionsFlow), findsNothing);
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });
  });

  group('history back label', () {
    testWidgets('an unlabelled flow shows a plain back control', (
      tester,
    ) async {
      final ledger = Ledger(state: defaultState());
      final container = overviewContainer(ledger);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: TransactionsFlow(onEnded: () {})),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
      expect(find.bySemanticsLabel('Overview'), findsNothing);
    });
  });

  group('shell wiring', () {
    Future<ProviderContainer> pumpShell(
      WidgetTester tester,
      ShellLayoutMode mode,
    ) async {
      tester.view.physicalSize = switch (mode) {
        ShellLayoutMode.phone => _phoneSize,
        ShellLayoutMode.open => _openSize,
        ShellLayoutMode.desktop => _desktopSize,
      };
      tester.view.devicePixelRatio = _testDevicePixelRatio;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          appBootProvider.overrideWith(
            (ref) => AppBoot(
              createStore: () async => InMemoryLedgerStore(),
              seedChanges: seedChanges,
            )..start(),
          ),
          analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
          shellLayoutModeProvider.overrideWithValue(mode),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BootChrome()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> tapViewHistory(WidgetTester tester) async {
      final action = find.widgetWithText(TextButton, 'View History');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
    }

    testWidgets('phone pushes history inside overview and keeps it selected', (
      tester,
    ) async {
      final container = await pumpShell(tester, ShellLayoutMode.phone);

      await tapViewHistory(tester);

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.overview,
      );
      final historyState = tester.state(find.byType(TransactionsFlow));

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.trends;
      await tester.pumpAndSettle();
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(tester.state(find.byType(TransactionsFlow)), same(historyState));
    });

    testWidgets('system Back preserves History in an inactive destination', (
      tester,
    ) async {
      final container = await pumpShell(tester, ShellLayoutMode.phone);
      await tapViewHistory(tester);
      final historyState = tester.state(find.byType(TransactionsFlow));

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.trends;
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.trends,
      );
      expect(find.byType(TransactionsFlow), findsNothing);
      expect(
        tester.state(find.byType(TransactionsFlow, skipOffstage: false)),
        same(historyState),
      );

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(tester.state(find.byType(TransactionsFlow)), same(historyState));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(TransactionsFlow), findsNothing);
      expect(find.text('Recent entries'), findsOneWidget);
      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.overview,
      );

      await tapViewHistory(tester);

      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(
        tester.state(find.byType(TransactionsFlow)),
        isNot(same(historyState)),
      );
    });

    testWidgets('desktop selects the history destination', (tester) async {
      final container = await pumpShell(tester, ShellLayoutMode.desktop);

      await tapViewHistory(tester);

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('open mode selects the shell History destination', (
      tester,
    ) async {
      final container = await pumpShell(tester, ShellLayoutMode.open);

      await tapViewHistory(tester);

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('phone History route survives open and phone resizing', (
      tester,
    ) async {
      tester.view.physicalSize = _phoneSize;
      tester.view.devicePixelRatio = _testDevicePixelRatio;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          appBootProvider.overrideWith(
            (ref) => AppBoot(
              createStore: () async => InMemoryLedgerStore(),
              seedChanges: seedChanges,
            )..start(),
          ),
          analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
          shellPlatformProvider.overrideWithValue((
            isWeb: false,
            targetPlatform: TargetPlatform.android,
          )),
          shellWindowSizeProvider.overrideWith(
            (ref) => ref.watch(_responsiveWindowSizeProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BootChrome()),
        ),
      );
      await tester.pumpAndSettle();
      await tapViewHistory(tester);
      final historyState = tester.state(find.byType(TransactionsFlow));

      tester.view.physicalSize = _openSize;
      container.read(_responsiveWindowSizeProvider.notifier).state = _openSize;
      await tester.pumpAndSettle();

      expect(container.read(shellLayoutModeProvider), ShellLayoutMode.open);
      expect(tester.state(find.byType(TransactionsFlow)), same(historyState));

      tester.view.physicalSize = _phoneSize;
      container.read(_responsiveWindowSizeProvider.notifier).state = _phoneSize;
      await tester.pumpAndSettle();

      expect(container.read(shellLayoutModeProvider), ShellLayoutMode.phone);
      expect(tester.state(find.byType(TransactionsFlow)), same(historyState));
    });
  });
}
