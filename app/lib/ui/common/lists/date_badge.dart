import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _badgeWidth = 30.0;

const _dayFontSize = 18.0;

const _dayFontWeight = FontWeight.w600;

const _monthFontSize = 10.0;

const _badgeLineHeight = 1.05;

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
            style: const TextStyle(
              fontSize: _dayFontSize,
              fontWeight: _dayFontWeight,
              height: _badgeLineHeight,
            ),
          ),
          Text(
            month,
            style: TextStyle(
              fontSize: _monthFontSize,
              color: colors.subtext,
              height: _badgeLineHeight,
            ),
          ),
        ],
      ),
    );
  }
}
