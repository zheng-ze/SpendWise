import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);
const _titleLineHeight = 1.12;
const _backHitHeight = 48.0;
const _backIconSize = 18.0;
const _backIconGap = 2.0;
const _backRadius = BorderRadius.all(Radius.circular(8));
const _backPadding = EdgeInsets.only(bottom: 4);
const _backWidthFactor = 1.0;

// MARK: - PageHeader
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.backLabel,
    this.onBack,
  }) : assert(
         (backLabel == null) == (onBack == null),
         'backLabel and onBack go together',
       );

  final String title;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final label = backLabel;
    final onBack = this.onBack;
    final back = label == null || onBack == null
        ? null
        : Padding(
            padding: _backPadding,
            child: _PageHeaderBack(label: label, onPressed: onBack),
          );
    final titleStyle = context.text.headline.copyWith(
      fontWeight: FontWeight.w600,
      height: _titleLineHeight,
      color: context.colors.text,
    );
    final heading = Semantics(
      header: true,
      child: Text(title, style: titleStyle),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [?back, heading],
    );

    return Padding(
      padding: _pagePadding,
      child: SizedBox(width: double.infinity, child: column),
    );
  }
}

// MARK: - PageHeaderBack
class _PageHeaderBack extends StatelessWidget {
  const _PageHeaderBack({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final action = context.colors.action;
    final style = context.text.small.copyWith(color: action);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.chevron_left, size: _backIconSize, color: action),
        const SizedBox(width: _backIconGap),
        Text(label, style: style),
      ],
    );
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        borderRadius: _backRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _backHitHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _backWidthFactor,
            child: content,
          ),
        ),
      ),
    );
  }
}
