import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/amount_input.dart';

// MARK: - Constants
const _amountLabel = 'Monthly limit / SGD';
const _amountHint = 'Limit';
const _emptyAmountDisplay = '0.00';
const _labelGap = 4.0;

bool usesBudgetAmountPad(BuildContext context) =>
    AppSheetAlertSlot.maybeOf(context)?.presentation !=
    AppSheetPresentation.desktop;

// MARK: - BudgetAmountInput
class BudgetAmountInput extends StatelessWidget {
  const BudgetAmountInput({
    super.key,
    required this.controller,
    required this.amountText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String amountText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(_amountLabel, style: theme.textTheme.labelMedium);
    final empty = amountText.isEmpty;
    final display = Text(
      empty ? _emptyAmountDisplay : amountText,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: empty ? theme.hintColor : null,
      ),
    );
    final value = usesBudgetAmountPad(context)
        ? display
        : AmountField(
            controller: controller,
            allowsNegative: false,
            hintText: _amountHint,
            autofocus: true,
            onChanged: onChanged,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: _labelGap),
        value,
      ],
    );
  }
}

// MARK: - BudgetAmountPad
class BudgetAmountPad extends StatelessWidget {
  const BudgetAmountPad({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  void _apply(AmountEdit edit) {
    final current = controller.value;
    final next = applyAmountEdit(current, edit);
    if (next == current) return;
    controller.value = next;
    onChanged(next.text);
  }

  @override
  Widget build(BuildContext context) {
    return NumberPad(
      enabled: true,
      onDigit: (digit) => _apply(AmountEdit.insert(digit)),
      onDecimal: () => _apply(const AmountEdit.insert('.')),
      onBackspace: () => _apply(const AmountEdit.delete()),
    );
  }
}
