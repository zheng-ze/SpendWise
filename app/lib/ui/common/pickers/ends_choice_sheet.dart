import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/choice_tile.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const _titleLabel = 'Ends';

const _neverLabel = 'Never';

const _chooseDateLabel = 'Choose date';

// MARK: - EndsChoice
enum EndsChoice { never, chooseDate }

// MARK: - Show
Future<EndsChoice?> showEndsChoiceSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) presentation,
  required bool hasEndDate,
  PickerRouteCallback? onRouteCreated,
}) {
  final never = ChoiceTile<EndsChoice>(
    label: _neverLabel,
    value: EndsChoice.never,
    selected: !hasEndDate,
  );
  final chooseDate = ChoiceTile<EndsChoice>(
    label: _chooseDateLabel,
    value: EndsChoice.chooseDate,
    selected: hasEndDate,
  );
  final sheet = AppPickerSheet(
    title: _titleLabel,
    body: Column(children: [never, chooseDate]),
  );
  return showPickerAppSheet<EndsChoice>(
    context,
    presentation: presentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => sheet,
  );
}
