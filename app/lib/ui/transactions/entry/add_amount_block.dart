import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_input.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

const _blockRadius = Radius.circular(12.0);

const _blockPadding = EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0);

const _labelGap = 2.0;

const _idleUnderlineHeight = 1.0;

const _focusedUnderlineHeight = 2.0;

const _amountLabel = 'Amount / SGD';

const _amountHint = '0.00';

const _expenseSign = '-';

const _incomeSign = '+';

const _noSign = '';

class AddAmountBlock extends StatelessWidget {
  const AddAmountBlock({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.kind,
    required this.systemKeyboard,
    required this.onChanged,
    required this.onTapOutside,
    required this.onTapUpOutside,
  });

  final TextEditingController controller;

  final FocusNode focusNode;

  final EntryFormKind kind;

  final bool systemKeyboard;

  final ValueChanged<String> onChanged;

  final TapRegionCallback onTapOutside;

  final TapRegionUpCallback onTapUpOutside;

  String get _sign => switch (kind) {
    EntryFormKind.expense => _expenseSign,
    EntryFormKind.income => _incomeSign,
    EntryFormKind.transfer => _noSign,
  };

  Color _tone(SpendWiseColors colors) => switch (kind) {
    EntryFormKind.expense => colors.expense,
    EntryFormKind.income => colors.income,
    EntryFormKind.transfer => colors.text,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.hero.copyWith(color: _tone(colors));
    final label = Text(
      _amountLabel,
      style: context.text.small.copyWith(color: colors.subtext),
    );
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onTapOutside: onTapOutside,
      onTapUpOutside: onTapUpOutside,
      keyboardType: systemKeyboard
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.none,
      inputFormatters: const [AmountInputFormatter(allowsNegative: false)],
      style: style,
      decoration: const InputDecoration.collapsed(hintText: _amountHint),
    );
    final amountRow = Row(
      children: [
        if (_sign.isNotEmpty) Text(_sign, style: style),
        Expanded(child: field),
      ],
    );
    final content = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: _blockRadius),
      ),
      padding: _blockPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: _labelGap),
          amountRow,
        ],
      ),
    );
    final underline = ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) => Container(
        height: focusNode.hasFocus
            ? _focusedUnderlineHeight
            : _idleUnderlineHeight,
        color: focusNode.hasFocus ? colors.action : colors.edge,
      ),
    );
    final block = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [content, underline],
    );

    return TextFieldTapRegion(
      child: GestureDetector(onTap: focusNode.requestFocus, child: block),
    );
  }
}
