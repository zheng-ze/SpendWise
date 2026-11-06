import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/id_selection.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - HistoryEntrySelectionNotifier
class HistoryEntrySelectionNotifier extends IdSelectionNotifier {
  @override
  String? build() {
    ref.watch(
      shellLayoutModeProvider.select((mode) => mode == ShellLayoutMode.phone),
    );
    return super.build();
  }
}

// MARK: - Provider
final historyEntrySelectionProvider =
    NotifierProvider.autoDispose<HistoryEntrySelectionNotifier, String?>(
      HistoryEntrySelectionNotifier.new,
      dependencies: [shellLayoutModeProvider],
    );
