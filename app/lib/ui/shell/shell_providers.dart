import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/providers.dart';

enum ShellDestination { transactions, stats, accounts }

final selectedDestinationProvider = StateProvider<ShellDestination>(
  (ref) => ShellDestination.transactions,
);

DateTime startOfMonthUtc(DateTime date) => DateTime.utc(date.year, date.month);

final selectedMonthProvider = StateProvider<DateTime?>((ref) => null);

final effectiveMonthProvider = Provider<DateTime>((ref) {
  final override = ref.watch(selectedMonthProvider);
  if (override != null) return startOfMonthUtc(override);
  return startOfMonthUtc(ref.watch(todayProvider));
});

final enrollmentFlowOpenProvider = StateProvider<bool>((ref) => false);

final settingsOpenProvider = StateProvider<bool>((ref) => false);
