import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/id_selection.dart';

// MARK: - Constants
final selectedPlanProvider =
    NotifierProvider.autoDispose<IdSelectionNotifier, String?>(
      IdSelectionNotifier.new,
    );
