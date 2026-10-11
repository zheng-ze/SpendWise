import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/providers.dart';

enum ShellDestination { transactions, stats, accounts, settings }

enum ShellLayoutMode { phone, desktop }

ShellLayoutMode resolveShellLayoutMode({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) return ShellLayoutMode.desktop;
  switch (targetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return ShellLayoutMode.phone;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return ShellLayoutMode.desktop;
  }
}

final shellLayoutModeProvider = Provider<ShellLayoutMode>(
  (ref) => resolveShellLayoutMode(
    isWeb: kIsWeb,
    targetPlatform: defaultTargetPlatform,
  ),
);

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
