import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/tray.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.lines = _defaultLines});

  static const _defaultLines = 3;

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

  static const _barHeight = 12.0;

  static const _barRadius = 7.0;

  static const _wideFactor = 0.6;

  static const _narrowFactor = 0.4;

  static const _verticalPadding = 7.0;

  @override
  Widget build(BuildContext context) {
    final fill = Container(
      height: _barHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_barRadius),
      ),
    );
    final fraction = FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: wide ? _wideFactor : _narrowFactor,
      child: fill,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
      child: SizedBox(width: double.infinity, child: fraction),
    );
  }
}

class LoadingTrays extends StatelessWidget {
  const LoadingTrays({super.key, this.trays = _defaultTrays});

  static const _defaultTrays = 3;

  static const _trayGap = 10.0;

  final int trays;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < trays; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: _trayGap),
            child: Tray(child: LoadingSkeleton()),
          ),
      ],
    );
  }
}
