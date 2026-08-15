import 'package:flutter/material.dart';

Future<bool> showDeleteHolderConfirmation(
  BuildContext context, {
  required String name,
  required int referenceCount,
}) async {
  final entryWord = referenceCount == 1 ? 'transaction' : 'transactions';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $name?'),
      content: Text('$referenceCount $entryWord keep this name.'),
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
