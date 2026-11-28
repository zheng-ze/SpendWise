import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/shell/shell_navigation.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

import '../../support/shell_sheet_harness.dart';
import '../../support/ui_test_timeout.dart';
import '../budgets/budget_shell_test_support.dart';

const _shellSize = Size(1024, 800);
const _scopedFlow = TransactionsFlow(
  initialScope: TransactionsScope(
    title: 'Scoped',
    scopeIDs: {'a0000000-0000-0000-0000-000000000001'},
  ),
);

class _LoadingTransactionsNotifier extends TransactionsNotifier {
  _LoadingTransactionsNotifier(super.scope);

  @override
  TransactionsViewState build() {
    final built = super.build();
    Future.microtask(() {
      if (ref.mounted) state = const AsyncLoading();
    });
    return built;
  }
}

class _FailedTransactionsNotifier extends TransactionsNotifier {
  _FailedTransactionsNotifier(super.scope);

  @override
  TransactionsViewState build() {
    final built = super.build();
    Future.microtask(() {
      if (ref.mounted) state = AsyncError('failed', StackTrace.empty);
    });
    return built;
  }
}

ProviderContainer _shellContainer({List<Override> overrides = const []}) {
  return buildShellContainer(
    ledger: Ledger(state: LedgerState()),
    overrides: overrides,
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  ProviderContainer container, {
  Widget history = const TransactionsFlow(),
}) async {
  useShellWindow(tester, _shellSize);
  await pumpShellApp(
    tester,
    container,
    bodies: {
      ShellDestination.overview: (_) => const SizedBox.shrink(),
      ShellDestination.history: (_) => history,
    },
  );
}

void _requestTrends(ProviderContainer container) {
  container.read(shellNavigationProvider.notifier).openHistoryTrends();
}

Future<void> _pumpShellOnHistory(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _pumpShell(tester, container);
  container.read(shellNavigationProvider.notifier).selectHistory();
  await tester.pumpAndSettle();
}

Finder get _trends => find.byType(TrendsFlow, skipOffstage: false);

Future<void> _popSystemRoute(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

void _expectHistorySelected(ProviderContainer container) {
  expect(container.read(selectedDestinationProvider), ShellDestination.history);
}

void main() {
  testWidgets(
    'a request while Overview is selected opens Trends on History once',
    (tester) async {
      final container = _shellContainer();
      await _pumpShell(tester, container);
      expect(_trends, findsNothing);

      _requestTrends(container);
      await tester.pumpAndSettle();

      _expectHistorySelected(container);
      expect(_trends, findsOneWidget);
      expect(container.read(shellNavigationProvider), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a request made before History is ever built opens Trends on mount',
    (tester) async {
      final container = _shellContainer();
      _requestTrends(container);

      await _pumpShell(tester, container);

      _expectHistorySelected(container);
      expect(_trends, findsOneWidget);
      expect(container.read(shellNavigationProvider), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a request while the History view model is loading is honored once',
    (tester) async {
      final container = _shellContainer(
        overrides: [
          transactionsViewModelProvider(null)
              .overrideWith(() => _LoadingTransactionsNotifier(null)),
        ],
      );
      await _pumpShell(tester, container);

      _requestTrends(container);
      await tester.pumpAndSettle();

      expect(_trends, findsOneWidget);
      expect(container.read(shellNavigationProvider), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('duplicate requests while Trends is open keep the open route', (
    tester,
  ) async {
    final container = _shellContainer();
    await _pumpShell(tester, container);
    _requestTrends(container);
    await tester.pumpAndSettle();
    final openRoute = tester.state(_trends);

    _requestTrends(container);
    _requestTrends(container);
    await tester.pumpAndSettle();

    expect(_trends, findsOneWidget);
    expect(tester.state(_trends), same(openRoute));
    expect(container.read(shellNavigationProvider), isNull);
  }, timeout: uiTestTimeout);

  testWidgets(
    'Back after the redirect removes Trends and keeps History selected',
    (tester) async {
      final container = _shellContainer();
      await _pumpShell(tester, container);
      _requestTrends(container);
      await tester.pumpAndSettle();

      await _popSystemRoute(tester);
      await tester.pumpAndSettle();

      expect(_trends, findsNothing);
      _expectHistorySelected(container);
      expect(find.byType(TransactionsScreen), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a request while Trends is exiting stays pending then reopens it once',
    (tester) async {
      final container = _shellContainer();
      await _pumpShell(tester, container);
      _requestTrends(container);
      await tester.pumpAndSettle();

      await _popSystemRoute(tester);
      _requestTrends(container);
      await tester.pump();
      expect(container.read(shellNavigationProvider), isNotNull);

      await tester.pumpAndSettle();

      expect(_trends, findsOneWidget);
      expect(container.read(shellNavigationProvider), isNull);
      await _popSystemRoute(tester);
      await tester.pumpAndSettle();
      expect(_trends, findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'resizing between phone and open layouts retains the open Trends route',
    (tester) async {
      final container = _shellContainer();
      await _pumpShell(tester, container);
      _requestTrends(container);
      await tester.pumpAndSettle();
      final openRoute = tester.state(_trends);
      final mode = container.read(budgetShellModeFixture.notifier);

      mode.state = ShellLayoutMode.open;
      await tester.pumpAndSettle();
      expect(tester.state(_trends), same(openRoute));

      mode.state = ShellLayoutMode.phone;
      await tester.pumpAndSettle();
      expect(tester.state(_trends), same(openRoute));
      expect(_trends, findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a scoped flow never consumes a request and disposes with it pending',
    (tester) async {
      final container = _shellContainer();
      await _pumpShell(tester, container, history: _scopedFlow);

      _requestTrends(container);
      await tester.pumpAndSettle();

      expect(_trends, findsNothing);
      expect(container.read(shellNavigationProvider), isNotNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a flow disposed after a request but before its pickup runs does not throw',
    (tester) async {
      final container = _shellContainer();
      await _pumpShellOnHistory(tester, container);

      _requestTrends(container);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a request while the History view model has failed is honored once',
    (tester) async {
      final container = _shellContainer(
        overrides: [
          transactionsViewModelProvider(null)
              .overrideWith(() => _FailedTransactionsNotifier(null)),
        ],
      );
      await _pumpShell(tester, container);

      _requestTrends(container);
      await tester.pumpAndSettle();

      expect(_trends, findsOneWidget);
      expect(container.read(shellNavigationProvider), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a request while a sheet is open opens Trends once and keeps it after',
    (tester) async {
      final container = _shellContainer();
      await _pumpShellOnHistory(tester, container);
      final context = tester.element(find.byType(TransactionsFlow));
      final sheet = pushShellSheet(context);
      await tester.pumpAndSettle();

      _requestTrends(container);
      await tester.pumpAndSettle();
      expect(_trends, findsOneWidget);
      expect(container.read(shellNavigationProvider), isNull);

      await closeShellSheet(tester, sheet);
      expect(_trends, findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('a pending request is picked up when History is selected later', (
    tester,
  ) async {
    final container = _shellContainer();
    await _pumpShellOnHistory(tester, container);
    final destination = container.read(selectedDestinationProvider.notifier);

    _requestTrends(container);
    destination.state = ShellDestination.overview;
    await tester.pumpAndSettle();
    expect(_trends, findsNothing);
    expect(container.read(shellNavigationProvider), isNotNull);

    destination.state = ShellDestination.history;
    await tester.pumpAndSettle();

    expect(_trends, findsOneWidget);
    expect(container.read(shellNavigationProvider), isNull);
  }, timeout: uiTestTimeout);
}
