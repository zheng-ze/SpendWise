import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/persistence/store/ledger_store.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/boot_chrome.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/in_memory_ledger_store.dart';

class _GatedStoreFactory {
  _GatedStoreFactory();

  Completer<LedgerStore>? _pending;

  int startCount = 0;

  Future<LedgerStore> call() {
    startCount++;
    final gate = Completer<LedgerStore>();
    _pending = gate;
    return gate.future;
  }

  void fail(Object error) => _pending!.completeError(error);

  void succeed() => _pending!.complete(InMemoryLedgerStore());
}

void main() {
  Widget hostedIn(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: BootChrome()),
  );

  ProviderContainer containerWith(_GatedStoreFactory factory) {
    final container = ProviderContainer(
      overrides: [
        appBootProvider.overrideWith(
          (ref) =>
              AppBoot(createStore: factory.call, seedChanges: seedChanges)
                ..start(),
        ),
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('loading shows a progress indicator', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('failure shows the headline, a friendly message and retry', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(StateError('disk on fire'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your data"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('failure does not leak the raw exception text to the user', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(Exception('DriftException: disk image is malformed'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('DriftException: disk image is malformed'),
      findsNothing,
    );
    expect(
      find.textContaining("Something went wrong loading your data"),
      findsOneWidget,
    );
  });

  testWidgets('retry re-enters loading and re-runs boot', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(StateError('disk on fire'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("Couldn't load your data"), findsNothing);
    expect(factory.startCount, 2);
  });

  testWidgets('ready shows the shell', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.succeed();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('BootChrome injects scoped Money Add source into the shell', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    final container = containerWith(factory);
    await tester.pumpWidget(hostedIn(container));
    factory.succeed();
    await tester.pumpAndSettle();

    final accountState = await container.read(accountsViewModelProvider.future);
    final account = accountState.sections
        .expand((section) => section.rows)
        .firstWhere((row) => row.pockets.isNotEmpty);
    final pocketId = account.pockets.first.id;
    final observer = container.read(moneyNavigatorObserverProvider);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    container.read(accountsViewModelProvider.notifier).openAccount(account.id);
    await tester.pumpAndSettle();
    expect(observer.sourceId, account.id);

    Future<void> addAndExpectSource(String? expectedSourceId) async {
      final addControl = find.text('Add').evaluate().isNotEmpty
          ? find.text('Add')
          : find.text('Add entry');
      await tester.tap(addControl);
      await tester.pumpAndSettle();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        expectedSourceId,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }

    await addAndExpectSource(account.id);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.history;
    await tester.pumpAndSettle();
    expect(
      identical(container.read(moneyNavigatorObserverProvider), observer),
      isTrue,
    );
    await addAndExpectSource(null);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    await tester.pumpAndSettle();
    await addAndExpectSource(account.id);
    expect(observer.sourceId, account.id);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    container
        .read(accountsViewModelProvider.notifier)
        .openAccountAlone(account.id);
    await tester.pumpAndSettle();
    expect(observer.sourceId, account.id);
    await addAndExpectSource(account.id);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    container.read(accountsViewModelProvider.notifier).openPocket(pocketId);
    await tester.pumpAndSettle();
    expect(observer.sourceId, pocketId);
    await addAndExpectSource(pocketId);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(observer.sourceId, isNull);
    await addAndExpectSource(null);
  });

  testWidgets('ready shows real content in the overview tab, not an '
      'empty placeholder', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.succeed();
    await tester.pumpAndSettle();

    expect(find.byType(OverviewScreen), findsOneWidget);
  });
}
