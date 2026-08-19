import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';

// Throws on its first open and succeeds after, standing in for a transient
// connection failure that has cleared by the time retry runs.
class _FlakyOpener {
  var _calls = 0;

  Future<QueryExecutor> open() async {
    _calls += 1;
    if (_calls == 1) throw StateError('connection failed');
    return NativeDatabase.memory();
  }
}

void main() {
  test(
    'retryAfterAFailedConnectionReachesReadyInsteadOfFailingAgain',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final opener = _FlakyOpener();
      final container = ProviderContainer(
        overrides: [
          databaseConnectionProvider.overrideWith((ref) => opener.open()),
        ],
      );
      addTearDown(container.dispose);

      final boot = container.read(appBootProvider);
      while (boot.phase is! Failed) {
        await Future<void>.delayed(Duration.zero);
      }

      await boot.retry();

      expect(boot.phase, isA<Ready>());
    },
  );
}
