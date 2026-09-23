import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

class ErrorSection extends StatelessWidget {
  const ErrorSection({super.key, required this.subject, required this.error});

  /// What failed to save, worded to sit after "Could not save".
  final String subject;

  final LedgerError? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Could not save $subject: ${friendlyLedgerErrorMessage(error)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

// Exhaustive, so a new case fails the analyzer here instead of falling
// through to a raw toString.
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
