import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('storeProvider resolves without an override', () {
    final container = ProviderContainer(
      overrides: [
        databaseConnectionProvider.overrideWith(
          (ref) async => NativeDatabase.memory(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(storeProvider), isA<DriftLedgerStore>());
  });

  test('boot reaches Ready against a real Drift store', () async {
    final container = ProviderContainer(
      overrides: [
        databaseConnectionProvider.overrideWith(
          (ref) async => NativeDatabase.memory(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final boot = container.read(appBootProvider);
    while (boot.phase is Loading) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(boot.phase, isA<Ready>());
  });

  test('disposing the container closes the database', () async {
    final container = ProviderContainer(
      overrides: [
        databaseConnectionProvider.overrideWith(
          (ref) async => NativeDatabase.memory(),
        ),
      ],
    );

    final store = container.read(storeProvider) as DriftLedgerStore;
    await store.load();
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await expectLater(store.load(), throwsA(anything));
  });

  test('first launch seeds, so the real store boots with content', () async {
    final container = ProviderContainer(
      overrides: [
        databaseConnectionProvider.overrideWith(
          (ref) async => NativeDatabase.memory(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final boot = container.read(appBootProvider);
    while (boot.phase is Loading) {
      await Future<void>.delayed(Duration.zero);
    }

    final ready = boot.phase as Ready;
    expect(ready.ledger.state.entries, isNotEmpty);
    expect(ready.ledger.state.moneySources, isNotEmpty);
  });
}
