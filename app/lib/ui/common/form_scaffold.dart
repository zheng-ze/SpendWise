import 'package:flutter/material.dart';

const _sheetPadding = 16.0;

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
          padding: const EdgeInsets.all(_sheetPadding),
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

  static const _titleContentGap = 12.0;

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: _titleContentGap),
        Flexible(child: SingleChildScrollView(child: child)),
        error,
        const SizedBox(height: _sheetPadding),
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
