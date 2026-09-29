import 'package:flutter_riverpod/legacy.dart';

enum ShellDestination { transactions, stats, accounts, settings }

final selectedDestinationProvider = StateProvider<ShellDestination>(
  (ref) => ShellDestination.transactions,
);

DateTime startOfMonthUtc(DateTime date) => DateTime.utc(date.year, date.month);

final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => startOfMonthUtc(DateTime.now()),
);

// True while a repair route opened from Settings is on the stack, so the
// repair banner does not cover the already-open repair form.
final repairFlowOpenProvider = StateProvider<bool>((ref) => false);
