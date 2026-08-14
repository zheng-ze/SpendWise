import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/boot_chrome.dart';
import 'package:spendwise/ui/transactions/daily_transactions_screen.dart';

import '../../support/in_memory_ledger_store.dart';

/// Lets a test hold boot in Loading, then decide whether the run fails or
/// succeeds, so all three phases are reachable from one widget.
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

  testWidgets('failure shows the headline, the cause and retry', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(StateError('disk on fire'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your data"), findsOneWidget);
    expect(find.textContaining('disk on fire'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
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

  testWidgets('ready shows real content in the transactions tab, not an '
      'empty placeholder', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.succeed();
    await tester.pumpAndSettle();

    expect(find.byType(TransactionsScreen), findsOneWidget);
  });
}
