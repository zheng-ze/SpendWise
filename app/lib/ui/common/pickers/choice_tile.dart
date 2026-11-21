import 'package:flutter/material.dart';

// MARK: - Constants
const _checkIcon = Icons.check;

// MARK: - ChoiceTile
class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.value,
    this.selected = false,
    this.leading,
  });

  final String label;
  final T value;
  final bool selected;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final leadingIcon = leading == null ? null : Icon(leading);
    final trailing = selected ? const Icon(_checkIcon) : null;
    return ListTile(
      onTap: () => Navigator.of(context).pop(value),
      leading: leadingIcon,
      title: Text(label),
      trailing: trailing,
    );
  }
}
