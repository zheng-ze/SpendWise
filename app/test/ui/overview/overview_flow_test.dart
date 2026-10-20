import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/boot_chrome.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/in_memory_ledger_store.dart';
import 'overview_fixture.dart';
import '../../support/ui_test_timeout.dart';

const _phoneSize = Size(400, 800);
const _openSize = Size(960, 720);
const _desktopSize = Size(1200, 900);
const _testDevicePixelRatio = 1.0;
final _responsiveWindowSizeProvider = StateProvider<Size>((ref) => _phoneSize);

Future<ProviderContainer> _pumpOverviewFlow(
  WidgetTester tester, {
  required VoidCallback onHistorySelected,
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
        home: OverviewFlow(onHistorySelected: onHistorySelected),
      ),
    ),
  );
  if (!requestBeforeMount) {
    await tester.runAsync(() => settleAnalysis(container, ledger));
  }
  await tester.pumpAndSettle();
  return container;
}

Future<void> _requestHistory(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(overviewViewModelProvider.notifier).requestHistory();
  await tester.pumpAndSettle();
}

void main() {
  group('history selection', () {
    testWidgets('requests select History once and clear the step', (
      tester,
    ) async {
      var selections = 0;
      final container = await _pumpOverviewFlow(
        tester,
        onHistorySelected: () => selections++,
      );

      await _requestHistory(tester, container);

      expect(selections, 1);
      expect(find.byType(TransactionsFlow), findsNothing);
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    }, timeout: uiTestTimeout);

    testWidgets('a repeated request selects History again', (tester) async {
      var selections = 0;
      final container = await _pumpOverviewFlow(
        tester,
        onHistorySelected: () => selections++,
      );

      await _requestHistory(tester, container);
      await _requestHistory(tester, container);

      expect(selections, 2);
    }, timeout: uiTestTimeout);

    testWidgets('a request before mount is picked up once mounted', (
      tester,
    ) async {
      var selections = 0;
      final container = await _pumpOverviewFlow(
        tester,
        onHistorySelected: () => selections++,
        requestBeforeMount: true,
      );

      expect(selections, 1);
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    }, timeout: uiTestTimeout);
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
    }, timeout: uiTestTimeout);
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

    testWidgets('phone selects the History destination', (tester) async {
      final container = await pumpShell(tester, ShellLayoutMode.phone);

      await tapViewHistory(tester);

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    }, timeout: uiTestTimeout);

    for (final mode in ShellLayoutMode.values) {
      testWidgets('$mode mounts exactly one unscoped History flow', (
        tester,
      ) async {
        await pumpShell(tester, mode);

        expect(
          find.byType(TransactionsFlow, skipOffstage: false),
          findsOneWidget,
        );
      }, timeout: uiTestTimeout);
    }

    testWidgets('View History reveals the retained History flow', (
      tester,
    ) async {
      final container = await pumpShell(tester, ShellLayoutMode.phone);
      await tapViewHistory(tester);
      final historyState = tester.state(find.byType(TransactionsFlow));

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      await tester.pumpAndSettle();
      await tapViewHistory(tester);

      expect(tester.state(find.byType(TransactionsFlow)), same(historyState));
    }, timeout: uiTestTimeout);

    testWidgets('system Back at the History root keeps History selected', (
      tester,
    ) async {
      final container = await pumpShell(tester, ShellLayoutMode.phone);
      await tapViewHistory(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
      expect(find.byType(TransactionsFlow), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('desktop selects the history destination', (tester) async {
      final container = await pumpShell(tester, ShellLayoutMode.desktop);

      await tapViewHistory(tester);

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
      expect(find.byType(TransactionsFlow), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    }, timeout: uiTestTimeout);

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
    }, timeout: uiTestTimeout);

    testWidgets('selected History survives open and phone resizing', (
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
    }, timeout: uiTestTimeout);
  });
}
