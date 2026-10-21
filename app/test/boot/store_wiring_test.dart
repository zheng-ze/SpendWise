import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
