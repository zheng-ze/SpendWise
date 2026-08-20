import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';

/// Shows the current status message, sourced from [BannerState].
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A stack layer rather than a snackbar, since the message needs to persist
    // until the store clears it rather than auto-dismissing.
    final message = ref.watch(bannerStateProvider).message;
    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Center(
        child: Material(
          color: theme.colorScheme.inverseSurface.withValues(alpha: 0.92),
          shape: const StadiumBorder(),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              message,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onInverseSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
