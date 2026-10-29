import 'package:flutter_riverpod/flutter_riverpod.dart';

// MARK: - SelectedBudgetNotifier
class SelectedBudgetNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String budgetID) => state = budgetID;

  void clear() => state = null;
}

// MARK: - Constants
final selectedBudgetProvider =
    NotifierProvider<SelectedBudgetNotifier, String?>(
      SelectedBudgetNotifier.new,
    );
