import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/tray.dart';

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
    return Material(
      color: Tray.fillColor(context),
      shape: Tray.shape(context),
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
