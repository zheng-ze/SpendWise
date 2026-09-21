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

  test('a publication in the same call stack is visible synchronously', () {
    final before = fence.snapshot();

    bus.publish(const [DeleteEntry('row-1')]);

    // No await between publish and check: the broadcast is sync, so the
    // fence's listener has already run before publish returned.
    expect(fence.checkClean(before), isFalse);
  });

  test('the epoch bumps on any publication regardless of content', () {
    final first = fence.snapshot();

    bus.publish(const [DeleteEntry('row-1')]);
    final second = fence.snapshot();
    expect(second, isNot(first));

    // A different change shape still bumps the epoch by exactly one.
    bus.publish(const [DeleteCategory('row-2')]);
    expect(fence.snapshot(), second + 1);

    // Stamped sync publications bump it too.
    bus.publish(const [DeleteEntry('row-3')], stamps: const {});
    expect(fence.snapshot(), second + 2);

    expect(fence.checkClean(first), isFalse);
    expect(fence.checkClean(fence.snapshot()), isTrue);
  });

  test('install is idempotent: one publication bumps the epoch once', () {
    fence.install();
    fence.install();

    final before = fence.snapshot();
    bus.publish(const [DeleteEntry('row-1')]);

    expect(fence.snapshot(), before + 1);
  });

  test('uninstall stops observing and is safe to repeat', () async {
    final before = fence.snapshot();

    await fence.uninstall();
    await fence.uninstall();

    bus.publish(const [DeleteEntry('row-1')]);

    expect(fence.checkClean(before), isTrue);
  });

  test('uninstall without install is a safe no-op', () async {
    final fresh = MutationFence(bus);
    await fresh.uninstall();
    await fresh.uninstall();
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
