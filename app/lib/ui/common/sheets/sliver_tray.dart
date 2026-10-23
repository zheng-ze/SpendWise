import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/tray.dart';

class SliverTray extends StatelessWidget {
  const SliverTray({
    super.key,
    this.title,
    this.trailing,
    required this.slivers,
  });

  final String? title;
  final Widget? trailing;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final header = title == null
        ? const <Widget>[]
        : <Widget>[
            SliverToBoxAdapter(
              child: TrayHeader(title: title, trailing: trailing),
            ),
          ];
    final group = SliverMainAxisGroup(slivers: [...header, ...slivers]);
    final padded = SliverPadding(
      padding: const EdgeInsets.all(Tray.contentPadding),
      sliver: group,
    );
    return DecoratedSliver(
      decoration: Tray.decoration(context),
      sliver: padded,
    );
  }
}
