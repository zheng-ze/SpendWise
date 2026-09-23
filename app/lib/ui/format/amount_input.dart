import 'package:flutter/services.dart';

const int _maxFractionDigits = 2;
const int _zero = 0x30;
const int _nine = 0x39;

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
