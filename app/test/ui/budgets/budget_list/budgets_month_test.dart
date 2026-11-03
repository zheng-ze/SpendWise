import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_month.dart';

void main() {
  test(
    'Budgets month choice resets to the current month once its listener closes',
    () async {
      final container = ProviderContainer(
        overrides: [todayProvider.overrideWithValue(DateTime.utc(2026, 11, 2))],
      );
      addTearDown(container.dispose);

      final listener = container.listen(budgetsMonthProvider, (_, _) {});
      container.read(budgetsMonthChoiceProvider.notifier).state = DateTime.utc(
        2026,
        9,
      );
      expect(container.read(budgetsMonthProvider), DateTime.utc(2026, 9));

      listener.close();
      await container.pump();

      expect(container.exists(budgetsMonthChoiceProvider), isFalse);
      expect(container.exists(budgetsMonthProvider), isFalse);
      expect(container.read(budgetsMonthProvider), DateTime.utc(2026, 11));
    },
  );
}
