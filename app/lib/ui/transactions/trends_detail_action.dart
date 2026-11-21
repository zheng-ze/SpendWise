import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_link_button.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const trendsDetailActionLabel = 'See more detail';
const _horizontalInset = 13.0;

// MARK: - TrendsDetailAction
class TrendsDetailAction extends StatelessWidget {
  const TrendsDetailAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = AppLinkButton(
      label: trendsDetailActionLabel,
      onPressed: onPressed,
      color: context.colors.subtext,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalInset),
      child: Align(alignment: Alignment.centerRight, child: button),
    );
  }
}
