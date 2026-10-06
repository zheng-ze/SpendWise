import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

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

    final colors = context.colors;
    final onRetry = this.onRetry;
    final content = <Widget>[
      Text(
        'Could not save $subject: ${friendlyLedgerErrorMessage(error)}',
        style: TextStyle(color: colors.error, fontSize: 12, height: 1.45),
      ),
    ];
    if (onRetry != null) content.add(_RetryButton(onPressed: onRetry));

    return Container(
      decoration: BoxDecoration(
        color: colors.errorBg,
        border: Border.all(color: colors.error),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton(onPressed: onPressed, child: const Text('Retry')),
    );
  }
}

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
