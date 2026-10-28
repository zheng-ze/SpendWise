import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart'
    show DefaultLimitTarget, LimitEditTarget, MonthLimitTarget;
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

// MARK: - Constants
const _actionWidth = double.infinity;

// MARK: - Sheet Presenter
Future<Decimal?> showBudgetLimitEditSheet({
  required BuildContext context,
  required LimitEditTarget target,
}) {
  final (title, subtitle, current) = switch (target) {
    DefaultLimitTarget(:final current, :final effectiveFromMonth) => (
      'Default Budget',
      'Applies from '
          '${formatMonthLabel(DateTime.utc(effectiveFromMonth.year, effectiveFromMonth.month))} '
          'onward',
      current,
    ),
    MonthLimitTarget(:final month, :final current) => (
      formatMonthLabel(DateTime.utc(month.year, month.month)),
      null,
      current,
    ),
  };

  return showModalBottomSheet<Decimal>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => BudgetLimitEditSheet(
      title: title,
      subtitle: subtitle,
      current: current,
    ),
  );
}

// MARK: - BudgetLimitEditSheet
class BudgetLimitEditSheet extends StatefulWidget {
  const BudgetLimitEditSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.current,
  });

  final String title;
  final String? subtitle;
  final Decimal current;

  @override
  State<BudgetLimitEditSheet> createState() => _BudgetLimitEditSheetState();
}

// MARK: - BudgetLimitEditSheetState
class _BudgetLimitEditSheetState extends State<BudgetLimitEditSheet> {
  static const _subtitleGap = 4.0;
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
    final title = Text(widget.title, style: theme.textTheme.titleMedium);
    final subtitle = widget.subtitle == null
        ? null
        : Text(widget.subtitle!, style: theme.textTheme.bodySmall);
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
        if (subtitle != null) ...[
          const SizedBox(height: _subtitleGap),
          subtitle,
        ],
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
