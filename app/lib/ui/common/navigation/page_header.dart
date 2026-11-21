import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);
const _backPadding = EdgeInsets.only(bottom: 4);

// MARK: - PageHeader
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    final back = onBack == null
        ? null
        : Padding(
            padding: _backPadding,
            child: BackButton(onPressed: onBack, color: context.colors.text),
          );
    final titleStyle = context.text.headline.copyWith(
      fontWeight: SpendWiseText.semibold,
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
