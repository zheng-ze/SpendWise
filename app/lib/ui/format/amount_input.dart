import 'package:flutter/services.dart';

// MARK: - Constants
const int _maxFractionDigits = 2;
const int _zero = 0x30;
const int _nine = 0x39;

// MARK: - Helpers
String sanitizeAmount(String text, {required bool allowsNegative}) {
  final buffer = StringBuffer();
  var seenPoint = false;
  var fractionDigits = 0;

  for (var i = 0; i < text.length; i++) {
    final char = text[i];

    if (char == '-') {
      if (allowsNegative && buffer.isEmpty) buffer.write(char);
      continue;
    }

    if (char == '.') {
      if (seenPoint) continue;
      seenPoint = true;
      buffer.write(char);
      continue;
    }

    if (char.codeUnitAt(0) < _zero || char.codeUnitAt(0) > _nine) continue;

    if (seenPoint) {
      if (fractionDigits == _maxFractionDigits) continue;
      fractionDigits++;
    }
    buffer.write(char);
  }

  return buffer.toString();
}

// MARK: - AmountEdit
class AmountEdit {
  const AmountEdit.insert(String this.text);

  const AmountEdit.delete() : text = null;

  final String? text;
}

TextEditingValue applyAmountEdit(TextEditingValue current, AmountEdit edit) {
  final length = current.text.length;
  final selection = current.selection.isValid
      ? current.selection
      : TextSelection.collapsed(offset: length);
  final inserted = edit.text;
  var start = selection.start;
  if (inserted == null && selection.isCollapsed) {
    if (start == 0) return current;
    start -= 1;
  }
  final replaced = current.text.replaceRange(
    start,
    selection.end,
    inserted ?? '',
  );
  final candidate = TextEditingValue(
    text: replaced,
    selection: TextSelection.collapsed(offset: start + (inserted?.length ?? 0)),
  );
  return const AmountInputFormatter(allowsNegative: false)
      .formatEditUpdate(current, candidate);
}

// MARK: - AmountInputFormatter
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({required this.allowsNegative});

  final bool allowsNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = sanitizeAmount(newValue.text, allowsNegative: allowsNegative);
    if (text == newValue.text) return newValue;

    final removedBeforeCaret =
        newValue.selection.baseOffset -
        sanitizeAmount(
          newValue.text.substring(0, newValue.selection.baseOffset),
          allowsNegative: allowsNegative,
        ).length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: (newValue.selection.baseOffset - removedBeforeCaret).clamp(
          0,
          text.length,
        ),
      ),
    );
  }
}
