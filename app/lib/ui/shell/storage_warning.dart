import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

/// Warns the user when the browser cannot persist their data.
class StorageWarning extends ConsumerWidget {
  const StorageWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A fixed strip rather than the dismissible overlay, since losing the
    // ledger on tab close is not a condition that passes on its own.
    if (ref.watch(storageIsDurableProvider)) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This browser will not keep your data after you close the tab',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
