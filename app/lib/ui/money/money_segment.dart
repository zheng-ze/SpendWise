import 'package:flutter_riverpod/legacy.dart';

enum MoneySegment { budgets, accounts, plans }

final moneySegmentProvider = StateProvider.autoDispose<MoneySegment>(
  (ref) => MoneySegment.accounts,
);
