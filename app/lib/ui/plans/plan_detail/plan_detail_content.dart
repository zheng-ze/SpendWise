import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _contentPadding = EdgeInsets.all(12);
const _scrollPhysics = ClampingScrollPhysics();
const _frequencyGap = 2.0;
const _rowsTopGap = 6.0;
const _buttonsTopGap = 12.0;
const _rowPadding = EdgeInsets.symmetric(vertical: 4);
const _rowValueWeight = FontWeight.w600;
const _labelValueGap = 12.0;
const _nextLabel = 'Next';
const _accountLabel = 'Account';
const _startedLabel = 'Started';
const _lastAddedLabel = 'Last added';
const _endsLabel = 'Ends';
const _editLabel = 'Edit plan';
const _buttonsGap = 8.0;
const _deleteLabel = 'Delete plan';

// MARK: - PlanDetailContent
class PlanDetailContent extends StatelessWidget {
  const PlanDetailContent({
    super.key,
    required this.viewState,
    required this.onEdit,
    required this.onDelete,
  });

  final PlanDetailViewState viewState;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (viewState.phase == PlanDetailPhase.deleted) {
      return const SizedBox.shrink();
    }

    final amountColor = AmountStyle.of(context, kind: viewState.kind).color;
    final amount = Text(
      formatSignedMoney(viewState.amount, kind: viewState.kind),
      style: context.text.headline.copyWith(color: amountColor),
    );
    final frequency = Text(
      viewState.frequencyLabel,
      style: TextStyle(color: context.colors.subtext),
    );
    final rows = [
      _DetailRow(label: _nextLabel, value: viewState.next),
      _DetailRow(label: _accountLabel, value: viewState.account),
      _DetailRow(
        label: viewState.relationRow.label,
        value: viewState.relationRow.value,
      ),
      _DetailRow(label: _startedLabel, value: viewState.started),
      _DetailRow(label: _lastAddedLabel, value: viewState.lastAdded),
      _DetailRow(label: _endsLabel, value: viewState.ends),
    ];
    final editButton = PrimaryButton(label: _editLabel, onPressed: onEdit);
    final deleteButton = PrimaryButton(
      label: _deleteLabel,
      destructive: true,
      onPressed: onDelete,
    );
    final tray = Tray(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          amount,
          const SizedBox(height: _frequencyGap),
          frequency,
          const SizedBox(height: _rowsTopGap),
          ...rows,
          const SizedBox(height: _buttonsTopGap),
          editButton,
          const SizedBox(height: _buttonsGap),
          deleteButton,
        ],
      ),
    );

    final padded = Padding(padding: _contentPadding, child: tray);
    return ListView(physics: _scrollPhysics, children: [padded]);
  }
}

// MARK: - DetailRow
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: TextStyle(color: context.colors.subtext),
    );
    final valueText = Text(
      value,
      textAlign: TextAlign.end,
      style: const TextStyle(fontWeight: _rowValueWeight),
    );

    return Padding(
      padding: _rowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelText,
          const SizedBox(width: _labelValueGap),
          Expanded(child: valueText),
        ],
      ),
    );
  }
}
