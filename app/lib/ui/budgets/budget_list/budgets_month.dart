import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

final budgetsMonthChoiceProvider = StateProvider.autoDispose<DateTime?>(
  (ref) => null,
);

final budgetsMonthProvider = Provider.autoDispose<DateTime>((ref) {
  final choice = ref.watch(budgetsMonthChoiceProvider);
  if (choice != null) return startOfMonthUtc(choice);
  return startOfMonthUtc(ref.watch(todayProvider));
});
