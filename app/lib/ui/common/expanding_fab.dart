import 'package:flutter/material.dart';

class FabAction {
  const FabAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// A single action fires directly with no expansion. A second action turns
/// the button into a toggle: the `+` rotates into an `x`, labelled capsules
/// stack above it, and an invisible backdrop collapses it on an outside tap.
///
/// Place this as the last child of a `Stack` wrapping the screen body, not
/// in `Scaffold.floatingActionButton` — that slot's hit-testing is bounded
/// to the FAB's own footprint, so a backdrop built inside it could never
/// catch a tap anywhere else on screen.
class ExpandingFab extends StatefulWidget {
  const ExpandingFab({super.key, required this.primary, this.secondary});

  final FabAction primary;
  final FabAction? secondary;

  @override
  State<ExpandingFab> createState() => _ExpandingFabState();
}

class _ExpandingFabState extends State<ExpandingFab> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _collapse() {
    if (_expanded) setState(() => _expanded = false);
  }

  void _fire(VoidCallback onTap) {
    setState(() => _expanded = false);
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final secondary = widget.secondary;
    if (secondary == null) {
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FloatingActionButton(
            onPressed: widget.primary.onTap,
            child: Icon(widget.primary.icon),
          ),
        ),
      );
    }

    return Stack(
      children: [
        if (_expanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _collapse,
              child: const SizedBox.expand(),
            ),
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_expanded) ...[
                  _ActionCapsule(
                    action: secondary,
                    onTap: () => _fire(secondary.onTap),
                  ),
                  const SizedBox(height: 12),
                  _ActionCapsule(
                    action: widget.primary,
                    onTap: () => _fire(widget.primary.onTap),
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton(
                  onPressed: _toggle,
                  child: AnimatedRotation(
                    turns: _expanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(_expanded ? Icons.close : widget.primary.icon),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCapsule extends StatelessWidget {
  const _ActionCapsule({required this.action, required this.onTap});

  final FabAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action.label),
              const SizedBox(width: 8),
              Icon(action.icon, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
