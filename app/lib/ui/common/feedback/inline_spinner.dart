import 'package:flutter/material.dart';

const _defaultSize = 20.0;
const _strokeWidth = 2.0;

class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.size = _defaultSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CircularProgressIndicator(strokeWidth: _strokeWidth),
    );
  }
}
