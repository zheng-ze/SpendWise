import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';

// MARK: - Constants
const _bannerElevation = 3.0;
const _messageHorizontalInset = 0.0;
const _bannerBottom = 0.0;

// MARK: - StatusBanner
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key, this.rightGutter = 0});

  final double rightGutter;

  static const _messageBackgroundOpacity = 0.92;

  static const _messagePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(bannerStateProvider).message;
    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return _BottomAnchored(
      left: _messageHorizontalInset,
      right: _messageHorizontalInset + rightGutter,
      child: Center(
        child: Material(
          color: theme.colorScheme.inverseSurface.withValues(
            alpha: _messageBackgroundOpacity,
          ),
          shape: const StadiumBorder(),
          elevation: _bannerElevation,
          child: Padding(
            padding: _messagePadding,
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

// MARK: - BottomAnchored
// The rail layout has no bottom bar to consume the system inset.
class _BottomAnchored extends StatelessWidget {
  const _BottomAnchored({
    required this.left,
    required this.right,
    required this.child,
  });

  final double left;
  final double right;
  final Widget child;

  static const _safeAreaBottomMargin = EdgeInsets.only(bottom: 16);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      bottom: _bannerBottom,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: _safeAreaBottomMargin,
        child: child,
      ),
    );
  }
}
