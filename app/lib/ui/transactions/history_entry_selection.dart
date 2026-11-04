import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - HistoryEntrySelectionNotifier
class HistoryEntrySelectionNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(
      shellLayoutModeProvider.select((mode) => mode == ShellLayoutMode.phone),
    );
    return null;
  }

  void select(String entryId) => state = entryId;

  void clear() => state = null;
}

// MARK: - Provider
final historyEntrySelectionProvider =
    NotifierProvider.autoDispose<HistoryEntrySelectionNotifier, String?>(
      HistoryEntrySelectionNotifier.new,
      dependencies: [shellLayoutModeProvider],
    );
