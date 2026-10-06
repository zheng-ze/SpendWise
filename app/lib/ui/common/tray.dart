import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

class Tray extends StatelessWidget {
  const Tray({super.key, this.title, this.trailing, required this.child});

  final String? title;

  final Widget? trailing;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = this.title;
    final header = title == null
        ? null
        : _TrayHeader(title: title, trailing: trailing);
    final content = <Widget>[];
    if (header != null) content.add(header);
    content.add(child);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.edge),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

class _TrayHeader extends StatelessWidget {
  const _TrayHeader({required this.title, required this.trailing});

  final String title;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
    );
    final trailing = this.trailing;
    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: titleText,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: titleText),
          trailing,
        ],
      ),
    );
  }
}
