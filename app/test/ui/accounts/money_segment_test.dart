import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/money/money_flow.dart';

void main() {
  test(
    'Money segment defaults to Accounts and resets once its listener closes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(moneySegmentProvider), MoneySegment.accounts);

      final listener = container.listen(moneySegmentProvider, (_, _) {});
      container.read(moneySegmentProvider.notifier).state = MoneySegment.plans;
      expect(container.read(moneySegmentProvider), MoneySegment.plans);

      listener.close();
      await container.pump();

      expect(container.exists(moneySegmentProvider), isFalse);
      expect(container.read(moneySegmentProvider), MoneySegment.accounts);
    },
  );
}
