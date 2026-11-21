import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _badgeWidth = 30.0;

// MARK: - DateBadge
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.day, required this.month});

  final String day;

  final String month;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: _badgeWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: context.text.title.copyWith(
              fontWeight: SpendWiseText.semibold,
            ),
          ),
          Text(
            month,
            style: context.text.caption.copyWith(color: colors.subtext),
          ),
        ],
      ),
    );
  }
}
