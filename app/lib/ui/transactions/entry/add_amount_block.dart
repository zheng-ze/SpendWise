import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_input.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Visual Constants

const _blockRadius = 12.0;

const _blockBorderWidth = 1.0;

const _blockPadding = EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0);

const _labelGap = 2.0;

const _amountLabel = 'Amount / SGD';

const _amountHint = '0.00';

// MARK: - AddAmountBlock
class AddAmountBlock extends StatelessWidget {
  const AddAmountBlock({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.systemKeyboard,
    required this.onChanged,
  });

  final TextEditingController controller;

  final FocusNode focusNode;

  final bool systemKeyboard;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final decoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_blockRadius),
      border: Border.all(color: colors.edge, width: _blockBorderWidth),
    );
    final label = Text(
      _amountLabel,
      style: context.text.small.copyWith(color: colors.subtext),
    );
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: systemKeyboard
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.none,
      inputFormatters: const [AmountInputFormatter(allowsNegative: false)],
      style: context.text.hero.copyWith(color: colors.text),
      decoration: const InputDecoration.collapsed(hintText: _amountHint),
    );

    return Container(
      decoration: decoration,
      padding: _blockPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: _labelGap),
          field,
        ],
      ),
    );
  }
}
