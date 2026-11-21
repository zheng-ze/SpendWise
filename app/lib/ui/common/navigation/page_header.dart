import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);
const _backPadding = EdgeInsets.only(bottom: 4);

// MARK: - PageHeader
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.disabledBack = false,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final bool disabledBack;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasBack = onBack != null || disabledBack;
    final enabledBack = BackButton(onPressed: onBack, color: colors.text);
    final disabledBackButton = IconButton(
      icon: const BackButtonIcon(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: null,
    );
    final back = onBack != null ? enabledBack : disabledBackButton;
    final backRow = !hasBack && trailing == null
        ? null
        : Padding(
            padding: _backPadding,
            child: Row(
              children: [?(hasBack ? back : null), const Spacer(), ?trailing],
            ),
          );
    final titleStyle = context.text.headline.copyWith(color: colors.text);
    final heading = Semantics(
      header: true,
      child: Text(title, style: titleStyle),
    );
    final subtitle = this.subtitle;
    final subtitleStyle = context.text.body.copyWith(color: colors.subtext);
    final subtitleText = subtitle == null
        ? null
        : Text(subtitle, style: subtitleStyle);

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [?backRow, heading, ?subtitleText],
    );

    return Padding(
      padding: _pagePadding,
      child: SizedBox(width: double.infinity, child: column),
    );
  }
}
