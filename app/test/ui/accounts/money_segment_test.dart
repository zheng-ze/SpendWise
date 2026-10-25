import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/money/money_flow.dart';

void main() {
  test('Money opens Accounts first and retains the selected segment', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(moneySegmentProvider), MoneySegment.accounts);

    container.read(moneySegmentProvider.notifier).state = MoneySegment.plans;

    expect(container.read(moneySegmentProvider), MoneySegment.plans);
  });
}
