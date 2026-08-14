import 'package:flutter/material.dart';

class ErrorSection extends StatelessWidget {
  const ErrorSection({super.key, required this.subject, required this.error});

  /// What failed to save, worded to sit after "Could not save".
  final String subject;

  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Could not save $subject: $error',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
