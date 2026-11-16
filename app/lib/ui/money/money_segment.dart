import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

enum MoneySegment { budgets, accounts, plans }

class MoneySegmentNotifier extends Notifier<MoneySegment> {
  @override
  MoneySegment build() {
    ref.listen(selectedDestinationProvider, (_, next) {
      if (next != ShellDestination.money) state = MoneySegment.accounts;
    });
    return MoneySegment.accounts;
  }

  void show(MoneySegment segment) => state = segment;

  void openAt(MoneySegment segment) {
    state = segment;
    ref.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
  }
}

final moneySegmentProvider =
    NotifierProvider<MoneySegmentNotifier, MoneySegment>(
      MoneySegmentNotifier.new,
    );
