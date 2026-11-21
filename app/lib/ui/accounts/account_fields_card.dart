import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/accounts/account_fields.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/inputs/form_section_card.dart';
import 'package:spendwise/ui/common/inputs/statement_day_picker.dart';
import 'package:spendwise/ui/common/pickers/account_type_picker.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

// MARK: - Constants

const accountFieldGap = 16.0;
const _nameHint = 'Name';

// MARK: - AccountFieldsCard
class AccountFieldsCard extends StatefulWidget {
  const AccountFieldsCard({
    super.key,
    required this.fields,
    required this.actions,
    required this.balanceHint,
    this.showsTypeFields = true,
    this.showsBalance = true,
    this.extras = const [],
  });

  final AccountFields fields;
  final AccountFieldsActions actions;
  final String balanceHint;
  final bool showsTypeFields;
  final bool showsBalance;
  final List<Widget> extras;

  @override
  State<AccountFieldsCard> createState() => _AccountFieldsCardState();
}

class _AccountFieldsCardState extends State<AccountFieldsCard> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _balanceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.fields;
    final actions = widget.actions;
    if (_nameController.text != fields.name) {
      _nameController.text = fields.name;
    }
    if (_balanceController.text != fields.balanceText) {
      _balanceController.text = fields.balanceText;
    }

    const gap = SizedBox(height: accountFieldGap);
    final nameField = TextField(
      controller: _nameController,
      decoration: const InputDecoration(hintText: _nameHint),
      onChanged: actions.setName,
    );
    final typePicker = AccountTypePicker(
      selected: fields.type,
      onSelected: actions.setType,
      sheetPresentation: shellSheetPresentation,
    );
    final statementDayPicker = StatementDayPicker(
      selected: fields.statementDay,
      onSelected: actions.setStatementDay,
      sheetPresentation: shellSheetPresentation,
    );
    final balanceField = AmountField(
      controller: _balanceController,
      allowsNegative: true,
      hintText: widget.balanceHint,
      onChanged: actions.setBalance,
    );

    return FormSectionCard(
      padding: FormSectionCard.fieldsPadding,
      children: [
        nameField,
        if (widget.showsTypeFields) ...[gap, typePicker],
        if (widget.showsTypeFields && fields.type == AccountType.card) ...[
          gap,
          statementDayPicker,
        ],
        if (widget.showsBalance) ...[gap, balanceField],
        ...widget.extras,
      ],
    );
  }
}
