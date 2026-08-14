import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';

import '../support/recording_ledger_store.dart';

void main() {
  testWidgets(
    'a real platform lifecycle notification reaches the registered AppBoot',
    (tester) async {
      final store = RecordingLedgerStore(hasSeeded: true);
      final container = ProviderContainer(
        overrides: [storeProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final boot = container.read(appBootProvider);
      while (boot.phase is! Ready) {
        await tester.pump();
      }
      store.calls.clear();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(store.calls, contains(StoreCall.flushNow));
    },
  );
}
