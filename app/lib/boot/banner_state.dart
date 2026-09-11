import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/persistence/ledger_store.dart';

const _dismissAfter = Duration(seconds: 4);

/// The two banner channels are independent, so neither dismisses the other. A
/// plan error outranks a save message and clears only on its timer.
class BannerState extends ChangeNotifier {
  SaveBannerState _saveState = SaveBannerState.clear;

  String? _planError;

  Timer? _planErrorTimer;

  String? get message => _planError ?? _saveMessage;

  String? get _saveMessage => switch (_saveState) {
    SaveBannerState.clear => null,
    SaveBannerState.retrying => "Couldn't save changes, retrying",
    SaveBannerState.failedWillRetry =>
      "Couldn't save changes, will retry shortly",
    SaveBannerState.permanentlyFailed => "Couldn't save changes",
  };

  // A clear means the store has nothing to report, never that a plan error
  // showing alongside it has been dismissed.
  void receiveSaveState(SaveBannerState state) {
    _saveState = state;
    notifyListeners();
  }

  void receivePlanErrors(List<PlanFailure> failures) {
    final planCount = failures.map((f) => f.planID).toSet().length;
    _planError = planCount == 1
        ? "A recurring plan couldn't add its entry"
        : "$planCount recurring plans couldn't add their entries";

    _planErrorTimer?.cancel();
    _planErrorTimer = Timer(_dismissAfter, _clearPlanError);
    notifyListeners();
  }

  void _clearPlanError() {
    _planError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _planErrorTimer?.cancel();
    super.dispose();
  }
}
