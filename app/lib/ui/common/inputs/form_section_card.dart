import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - FormSectionCard
class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    this.padding = defaultPadding,
    required this.children,
  });

  static const defaultPadding = EdgeInsets.symmetric(horizontal: 10.0);

  static const fieldsPadding = EdgeInsets.symmetric(
    horizontal: 10.0,
    vertical: 6.0,
  );

  final EdgeInsetsGeometry padding;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Tray.cornerRadius),
      side: BorderSide(color: colors.edge, width: Tray.borderWidth),
    );

    return Material(
      color: colors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
