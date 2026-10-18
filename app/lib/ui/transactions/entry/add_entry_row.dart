import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Visual Constants

const _textSize = 12.0;

const _valueWeight = FontWeight.w500;

const _labelValueGap = 10.0;

const _stackedGap = 4.0;

const _minValueWidth = 48.0;

const _chevronSize = 13.0;

const _chevronGap = 4.0;

const _labelIconSize = 14.0;

const _labelIconGap = 6.0;

const _keypadVerticalPadding = 8.0;

const _restVerticalPadding = 10.0;

// MARK: - Styles
TextStyle addRowValueStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: _textSize,
    fontWeight: _valueWeight,
    color: context.colors.text,
  );
}

// MARK: - AddEntryRow
class AddEntryRow extends StatelessWidget {
  const AddEntryRow({
    super.key,
    required this.label,
    required this.value,
    required this.keypad,
    this.chevron = false,
    this.labelIcon,
    this.onTap,
  });

  final String label;
  final Widget value;
  final bool keypad;
  final bool chevron;
  final IconData? labelIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = Theme.of(context).textTheme.bodyMedium!
        .copyWith(fontSize: _textSize, color: colors.subtext);
    final styledValue = DefaultTextStyle.merge(
      style: addRowValueStyle(context),
      child: value,
    );
    final chevronIcon = Padding(
      padding: const EdgeInsets.only(left: _chevronGap),
      child: Icon(
        Icons.chevron_right,
        size: _chevronSize,
        color: colors.subtext,
      ),
    );
    final valueCell = Row(
      children: [
        Expanded(child: styledValue),
        if (chevron) chevronIcon,
      ],
    );
    final trailingWidth = chevron ? _chevronGap + _chevronSize : 0.0;
    final icon = labelIcon;
    final labelIconWidth = icon == null ? 0.0 : _labelIconSize + _labelIconGap;
    final labelText = icon == null
        ? Text(label, style: labelStyle)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: _labelIconSize, color: colors.subtext),
              const SizedBox(width: _labelIconGap),
              Flexible(child: Text(label, style: labelStyle)),
            ],
          );
    final padding = EdgeInsets.symmetric(
      vertical: keypad ? _keypadVerticalPadding : _restVerticalPadding,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            _textWidth(context, label, labelStyle) +
            labelIconWidth +
            _labelValueGap +
            _minValueWidth +
            trailingWidth;
        final sideBySide = needed <= constraints.maxWidth;
        final content = sideBySide
            ? Row(
                children: [
                  labelText,
                  const SizedBox(width: _labelValueGap),
                  Expanded(child: valueCell),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText,
                  const SizedBox(height: _stackedGap),
                  valueCell,
                ],
              );
        return InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: content),
        );
      },
    );
  }

  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
