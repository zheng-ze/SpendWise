import 'package:flutter_riverpod/legacy.dart';

enum ShellDestination { transactions, stats, accounts, settings }

final selectedDestinationProvider = StateProvider<ShellDestination>(
  (ref) => ShellDestination.transactions,
);

DateTime startOfMonthUtc(DateTime date) => DateTime.utc(date.year, date.month);

final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => startOfMonthUtc(DateTime.now()),
);
