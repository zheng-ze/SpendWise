import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/persistence/store/ledger_store.dart';
import 'package:spendwise/ui/shell/boot_chrome.dart';

import '../../support/ui_test_timeout.dart';

class _GatedStoreFactory {
  _GatedStoreFactory();

  Completer<LedgerStore>? _pending;

  Future<LedgerStore> call() {
    final gate = Completer<LedgerStore>();
    _pending = gate;
    return gate.future;
  }

  void fail(Object error) => _pending!.completeError(error);
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
      find.textContaining('Something went wrong loading your data'),
      findsOneWidget,
    );
  }, timeout: uiTestTimeout);
}
