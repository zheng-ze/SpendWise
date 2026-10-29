import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/providers.dart';

// MARK: - ShellDestination
enum ShellDestination { overview, history, money, settings }

// MARK: - ShellLayoutMode
enum ShellLayoutMode { phone, open, desktop }

typedef ShellPlatformFacts = ({bool isWeb, TargetPlatform targetPlatform});

const openModeMinWidth = 600.0;
const openModeMinHeight = 480.0;

// MARK: - Helpers
ShellLayoutMode resolveShellLayoutMode({
  required bool isWeb,
  required TargetPlatform targetPlatform,
  required Size windowSize,
}) {
  if (isWeb) return ShellLayoutMode.desktop;
  switch (targetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      if (windowSize.width >= openModeMinWidth &&
          windowSize.height >= openModeMinHeight) {
        return ShellLayoutMode.open;
      }
      return ShellLayoutMode.phone;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return ShellLayoutMode.desktop;
  }
}

// MARK: - Layout Providers
final shellPlatformProvider = Provider<ShellPlatformFacts>(
  (ref) => (isWeb: kIsWeb, targetPlatform: defaultTargetPlatform),
);

final shellWindowSizeProvider = Provider<Size>((ref) => Size.zero);

final shellLayoutModeProvider = Provider<ShellLayoutMode>((ref) {
  final platform = ref.watch(shellPlatformProvider);
  return resolveShellLayoutMode(
    isWeb: platform.isWeb,
    targetPlatform: platform.targetPlatform,
    windowSize: ref.watch(shellWindowSizeProvider),
  );
}, dependencies: [shellPlatformProvider, shellWindowSizeProvider]);

final selectedDestinationProvider = StateProvider<ShellDestination>(
  (ref) => ShellDestination.overview,
);

// MARK: - Month Selection
DateTime startOfMonthUtc(DateTime date) => DateTime.utc(date.year, date.month);

final selectedMonthProvider = StateProvider<DateTime?>((ref) => null);

final effectiveMonthProvider = Provider<DateTime>((ref) {
  final override = ref.watch(selectedMonthProvider);
  if (override != null) return startOfMonthUtc(override);
  return startOfMonthUtc(ref.watch(todayProvider));
});

// MARK: - Enrollment
final enrollmentFlowOpenProvider = StateProvider<bool>((ref) => false);
