import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/sync/mutation_fence.dart';

void main() {
  late EventBus bus;
  late MutationFence fence;

  setUp(() {
    bus = EventBus();
    fence = MutationFence(bus);
    fence.install();
  });

  tearDown(() async {
    await fence.uninstall();
    await bus.dispose();
  });

  test('any publication makes the snapshot dirty immediately', () {
    final first = fence.snapshot();

    bus.publish(const [DeleteEntry('row-1')]);
    final second = fence.snapshot();
    expect(fence.checkClean(first), isFalse);

    bus.publish(const [DeleteCategory('row-2')]);
    expect(fence.checkClean(second), isFalse);

    bus.publish(const [DeleteEntry('row-3')], stamps: const {});
    expect(fence.checkClean(fence.snapshot()), isTrue);
  });

  test('uninstall stops observing and is safe to repeat', () async {
    final before = fence.snapshot();

    await fence.uninstall();
    await fence.uninstall();

    bus.publish(const [DeleteEntry('row-1')]);

    expect(fence.checkClean(before), isTrue);
  });

  test(
    'overlapping reinstall during in-flight uninstall stays installed',
    () async {
      final uninstalling = fence.uninstall();
      fence.install();

      final before = fence.snapshot();
      bus.publish(const [DeleteEntry('row-1')]);

      expect(fence.checkClean(before), isFalse);

      await uninstalling;
    },
  );
}
