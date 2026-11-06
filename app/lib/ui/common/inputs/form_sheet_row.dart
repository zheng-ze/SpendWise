import 'package:flutter/material.dart';

// MARK: - Constants
const _rowContentPadding = EdgeInsets.zero;

// MARK: - FormSheetRow
class FormSheetRow extends StatelessWidget {
  const FormSheetRow({
    super.key,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: _rowContentPadding,
        title: Text(label),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
