import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_presentation_controller.dart';

// MARK: - ShellLayoutModeScope
class ShellLayoutModeScope extends InheritedWidget {
  const ShellLayoutModeScope({
    super.key,
    required this.mode,
    required super.child,
  });

  final ShellLayoutMode mode;

  static ShellLayoutMode of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ShellLayoutModeScope>();
    assert(scope != null);
    return scope!.mode;
  }

  static ShellLayoutMode? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ShellLayoutModeScope>();
    return scope?.mode;
  }

  @override
  bool updateShouldNotify(ShellLayoutModeScope oldWidget) =>
      mode != oldWidget.mode;
}

// MARK: - ShellWindowBinding
class ShellWindowBinding extends StatelessWidget {
  const ShellWindowBinding({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    return ProviderScope(
      overrides: [shellWindowSizeProvider.overrideWithValue(windowSize)],
      child: _ShellLayoutModePublisher(child: child),
    );
  }
}

// MARK: - ShellLayoutModePublisher
class _ShellLayoutModePublisher extends ConsumerWidget {
  const _ShellLayoutModePublisher({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(shellLayoutModeProvider);
    return ShellLayoutModeScope(
      mode: mode,
      child: ShellPresentationScope(
        controller: ref.watch(shellPresentationControllerProvider),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

// MARK: - Shared Builder
Widget buildShellAppContent(BuildContext context, Widget? child) {
  return ShellWindowBinding(child: child);
}
