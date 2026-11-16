import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/money/money_segment.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('defaults to Accounts', () {
    expect(container.read(moneySegmentProvider), MoneySegment.accounts);
  });

  test('show changes the segment', () {
    container.read(moneySegmentProvider.notifier).show(MoneySegment.plans);

    expect(container.read(moneySegmentProvider), MoneySegment.plans);
  });

  test('leaving Money resets the segment to Accounts', () {
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    container.read(moneySegmentProvider.notifier).show(MoneySegment.plans);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.history;

    expect(container.read(moneySegmentProvider), MoneySegment.accounts);
  });

  test(
    'openAt selects Money and keeps the segment without a listener',
    () async {
      container
          .read(moneySegmentProvider.notifier)
          .openAt(MoneySegment.budgets);
      await container.pump();

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.money,
      );
      expect(container.read(moneySegmentProvider), MoneySegment.budgets);
    },
  );

  test('openAt after Plans gives Budgets', () {
    container.read(moneySegmentProvider.notifier).show(MoneySegment.plans);

    container.read(moneySegmentProvider.notifier).openAt(MoneySegment.budgets);

    expect(container.read(moneySegmentProvider), MoneySegment.budgets);
  });
}
