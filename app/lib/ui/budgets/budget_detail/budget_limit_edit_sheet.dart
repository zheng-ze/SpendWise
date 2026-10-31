import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';

// MARK: - Constants
const _actionWidth = double.infinity;
const _sheetTitle = 'Change limit';

// MARK: - Sheet Presenter
Future<Decimal?> showBudgetLimitEditSheet({
  required BuildContext context,
  required Decimal current,
}) {
  return showModalBottomSheet<Decimal>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => BudgetLimitEditSheet(current: current),
  );
}

// MARK: - BudgetLimitEditSheet
class BudgetLimitEditSheet extends StatefulWidget {
  const BudgetLimitEditSheet({super.key, required this.current});

  final Decimal current;

  @override
  State<BudgetLimitEditSheet> createState() => _BudgetLimitEditSheetState();
}

// MARK: - BudgetLimitEditSheetState
class _BudgetLimitEditSheetState extends State<BudgetLimitEditSheet> {
  static const _fieldGap = 12.0;
  static const _saveGap = 16.0;
  static const _sheetPadding = EdgeInsets.all(16);

  late final TextEditingController _controller = TextEditingController(
    text: formatPlainAmount(widget.current),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Text(_sheetTitle, style: theme.textTheme.titleMedium);
    final field = AmountField(
      controller: _controller,
      allowsNegative: false,
      hintText: 'Limit',
      autofocus: true,
    );
    final save = SizedBox(
      width: _actionWidth,
      child: FilledButton(
        onPressed: () {
          final amount = parseAmountInput(_controller.text);
          Navigator.of(context).pop(amount);
        },
        child: const Text('Save'),
      ),
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: _fieldGap),
        field,
        const SizedBox(height: _saveGap),
        save,
      ],
    );
    final padded = Padding(padding: _sheetPadding, child: column);
    final safe = SafeArea(child: padded);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: safe,
    );
  }
}
