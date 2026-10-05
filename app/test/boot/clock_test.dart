import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/shell/day_ticker.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

ProviderContainer _containerWith(DateTime Function() clock) {
  final container = ProviderContainer(
    overrides: [clockProvider.overrideWithValue(clock)],
  );
  addTearDown(container.dispose);
  return container;
}

DayTicker _tickerFor(ProviderContainer container) {
  final ticker = DayTicker(
    clock: container.read(clockProvider),
    onDayChanged: () => container.invalidate(todayProvider),
  );
  addTearDown(ticker.dispose);
  return ticker;
}

void main() {
  test('todayProvider derives UTC midnight from the clock', () {
    final container = _containerWith(() => DateTime(2026, 10, 3, 15, 30));

    expect(container.read(todayProvider), DateTime.utc(2026, 10, 3));
  });

  test('an app resume moves todayProvider to the new day', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    var now = DateTime(2026, 10, 3, 15, 30);
    final container = _containerWith(() => now);
    final ticker = _tickerFor(container);

    expect(container.read(todayProvider), DateTime.utc(2026, 10, 3));

    now = DateTime(2026, 10, 4, 1, 15);
    ticker.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(container.read(todayProvider), DateTime.utc(2026, 10, 4));
  });

  test('the midnight timer moves todayProvider to the new day', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FakeAsync().run((fake) {
      var now = DateTime(2026, 10, 3, 23, 59);
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(() => now)],
      );
      final ticker = DayTicker(
        clock: container.read(clockProvider),
        onDayChanged: () => container.invalidate(todayProvider),
      );

      expect(container.read(todayProvider), DateTime.utc(2026, 10, 3));

      now = DateTime(2026, 10, 4, 0, 1);
      fake.elapse(const Duration(minutes: 2));

      expect(container.read(todayProvider), DateTime.utc(2026, 10, 4));

      ticker.dispose();
      container.dispose();
    });
  });

  test('an unset month follows today into a new month', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    var now = DateTime(2026, 10, 3, 12);
    final container = _containerWith(() => now);
    final ticker = _tickerFor(container);

    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 10));

    now = DateTime(2026, 11, 2, 9);
    ticker.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 11));
  });

  test('a chosen month stays across a day rollover', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    var now = DateTime(2026, 10, 3, 12);
    final container = _containerWith(() => now);
    final ticker = _tickerFor(container);

    container.read(selectedMonthProvider.notifier).state = DateTime.utc(
      2026,
      9,
    );

    now = DateTime(2026, 11, 2, 9);
    ticker.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(container.read(todayProvider), DateTime.utc(2026, 11, 2));
    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 9));
  });
}
