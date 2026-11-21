import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - SectionLabel
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = _noPadding});

  final String text;
  final EdgeInsetsGeometry padding;

  static const _noPadding = EdgeInsets.zero;
  static const _weight = FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    final style = context.text.small.copyWith(
      color: context.colors.subtext,
      fontWeight: _weight,
    );
    return Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: style),
    );
  }
}
