import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/tray.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final bar = context.colors.tint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) _Bar(color: bar, wide: i.isEven),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.wide});

  final Color color;

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: SizedBox(
        width: double.infinity,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: wide ? 0.6 : 0.4,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingTrays extends StatelessWidget {
  const LoadingTrays({super.key, this.trays = 3});

  final int trays;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < trays; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Tray(child: LoadingSkeleton()),
          ),
      ],
    );
  }
}
