import 'package:flutter/material.dart';

// MARK: - Constants
const openSplitPrimaryKey = ValueKey('open-split-primary');
const openSplitSecondaryKey = ValueKey('open-split-secondary');
const _primaryFlex = 3;
const _secondaryFlex = 2;
const _columnGap = 10.0;

// MARK: - OpenSplitLayout
class OpenSplitLayout extends StatelessWidget {
  const OpenSplitLayout({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final primaryColumn = Expanded(
      flex: _primaryFlex,
      child: KeyedSubtree(key: openSplitPrimaryKey, child: primary),
    );
    final secondaryColumn = Expanded(
      flex: _secondaryFlex,
      child: KeyedSubtree(key: openSplitSecondaryKey, child: secondary),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        primaryColumn,
        const SizedBox(width: _columnGap),
        secondaryColumn,
      ],
    );
  }
}
