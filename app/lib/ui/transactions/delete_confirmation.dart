import 'package:flutter/material.dart';

/// Identifies the entry by its typed note, falling back to the row's title
/// when the note is empty.
Future<bool> showDeleteConfirmation(
  BuildContext context, {
  required String note,
  required String title,
}) async {
  final message = note.isEmpty ? title : note;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this transaction?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
