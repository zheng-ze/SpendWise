import 'package:flutter/material.dart';

// MARK: - LabelledBackButton
class LabelledBackButton extends StatelessWidget {
  const LabelledBackButton({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final button = BackButton(onPressed: onPressed);
    final label = this.label;
    if (label == null) return button;
    return Semantics(
      label: label,
      button: true,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}
