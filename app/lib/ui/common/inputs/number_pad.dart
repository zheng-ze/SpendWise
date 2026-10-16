import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _keyHeight = 48.0;

const _padRadius = 10.0;

const _padBorderWidth = 1.0;

const _backspaceIconSize = 20.0;

const _decimalLabel = 'Decimal point';

const _backspaceLabel = 'Backspace';

const _digitRows = [
  ['1', '2', '3'],
  ['4', '5', '6'],
  ['7', '8', '9'],
];

// MARK: - NumberPad

class NumberPad extends StatelessWidget {
  const NumberPad({
    super.key,
    required this.enabled,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
  });

  final bool enabled;

  final ValueChanged<String> onDigit;

  final VoidCallback onDecimal;

  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    VoidCallback? guard(VoidCallback callback) => enabled ? callback : null;
    Widget digit(String value) => _PadKey(
      semanticLabel: value,
      onTap: guard(() => onDigit(value)),
      child: Text(value, style: context.text.row),
    );
    final decimal = _PadKey(
      semanticLabel: _decimalLabel,
      onTap: guard(onDecimal),
      child: Text('.', style: context.text.row),
    );
    final backspace = _PadKey(
      semanticLabel: _backspaceLabel,
      onTap: guard(onBackspace),
      child: const Icon(Icons.backspace_outlined, size: _backspaceIconSize),
    );
    final rows = [
      for (final row in _digitRows) Row(children: row.map(digit).toList()),
      Row(children: [decimal, digit('0'), backspace]),
    ];
    final decoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_padRadius),
      border: Border.all(color: colors.edge, width: _padBorderWidth),
    );

    return DecoratedBox(
      decoration: decoration,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

// MARK: - Key

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final VoidCallback? onTap;

  final Widget child;

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final key = InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _keyHeight,
        child: Center(child: child),
      ),
    );
    final labelled = Semantics(
      label: semanticLabel,
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      child: key,
    );

    return Expanded(
      child: Material(type: MaterialType.transparency, child: labelled),
    );
  }
}
