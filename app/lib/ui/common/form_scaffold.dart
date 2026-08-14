import 'package:flutter/material.dart';

/// Cancel dismisses outright with no confirmation, so a caller that needs a
/// discard prompt has to wrap this rather than configure it.
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.canSave,
    required this.onSave,
    required this.child,
  });

  final String title;
  final bool canSave;
  final Future<void> Function() onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        leadingWidth: 88,
        actions: [
          TextButton(
            onPressed: canSave ? onSave : null,
            child: Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: canSave
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: child),
    );
  }
}
