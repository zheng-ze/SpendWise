import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/load_error_view.dart';

// MARK: - ErrorSection
class ErrorSection extends StatelessWidget {
  const ErrorSection({
    super.key,
    required this.subject,
    required this.error,
    this.onRetry,
  });

  final String subject;

  final LedgerError? error;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) return const SizedBox.shrink();

    return LoadErrorView.box(
      message: 'Could not save $subject: ${friendlyLedgerErrorMessage(error)}',
      onRetry: onRetry,
    );
  }
}

// MARK: - Helpers
String entrySaveErrorMessage(LedgerError error) =>
    'Could not save entry: ${friendlyLedgerErrorMessage(error)}';

String friendlyLedgerErrorMessage(LedgerError error) {
  return switch (error) {
    IdCollision() => 'that id is already in use.',
    UnknownAccount() => 'the account it refers to no longer exists.',
    UnknownHolder() => 'the account or pocket it refers to no longer exists.',
    UnknownCategory() => 'the category it refers to no longer exists.',
    UnknownEntry() => 'the entry it refers to no longer exists.',
    UnknownPlan() => 'the recurring plan it refers to no longer exists.',
    UnknownBudget() => 'the budget it refers to no longer exists.',
    ExhaustedPlan() => 'that recurring plan has already ended.',
    InactiveReference() => 'it refers to something that has been archived.',
    StaleResolutionCursor() =>
      'that recurring plan changed elsewhere; please try again.',
    SystemEntryLocked() => 'that entry is a system entry and cannot be edited.',
    ZeroAmount() => 'the amount cannot be zero.',
    CategoryTooDeep() => 'categories cannot be nested that deeply.',
    CategoryKindMismatch() =>
      'that category does not match the transaction kind.',
    CategoryAlreadyBudgeted() => 'that category already has a budget.',
  };
}
