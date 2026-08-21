import 'package:flutter/material.dart';

/// The bottom-sheet body shell shared by every form and receipt-style sheet
/// in this redesign: clears the keyboard, respects the safe area, and pads
/// the content, sizing to [children] instead of the sheet's full height.
class SheetShell extends StatelessWidget {
  const SheetShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.canSave,
    required this.onSave,
    required this.error,
    required this.child,
  });

  final String title;
  final bool canSave;
  final Future<void> Function() onSave;
  final Widget error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Flexible(child: SingleChildScrollView(child: child)),
        error,
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave ? onSave : null,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
