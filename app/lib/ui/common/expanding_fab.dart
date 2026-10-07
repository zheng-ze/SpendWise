import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

const _fabInset = 16.0;

const _actionGap = 12.0;

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

class ExpandingFab extends StatefulWidget {
  const ExpandingFab({super.key, required this.primary, this.secondary});

  final FabAction primary;
  final FabAction? secondary;

  @override
  State<ExpandingFab> createState() => _ExpandingFabState();
}

class _ExpandingFabState extends State<ExpandingFab> {
  static const _expandedTurns = 0.125;

  static const _toggleMillis = 200;

  static const _toggleDuration = Duration(milliseconds: _toggleMillis);

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
      return _SingleFab(action: widget.primary);
    }

    Widget? backdrop;
    if (_expanded) {
      backdrop = Positioned.fill(
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _collapse,
            child: const SizedBox.expand(),
          ),
        ),
      );
    }
    final expandedActions = <Widget>[
      _ActionCapsule(action: secondary, onTap: () => _fire(secondary.onTap)),
      const SizedBox(height: _actionGap),
      _ActionCapsule(
        action: widget.primary,
        onTap: () => _fire(widget.primary.onTap),
      ),
      const SizedBox(height: _actionGap),
    ];
    final toggle = FloatingActionButton(
      onPressed: _toggle,
      tooltip: _expanded ? 'Close menu' : widget.primary.label,
      child: AnimatedRotation(
        turns: _expanded ? _expandedTurns : 0,
        duration: _toggleDuration,
        child: Icon(_expanded ? Icons.close : widget.primary.icon),
      ),
    );
    final menu = Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(_fabInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [if (_expanded) ...expandedActions, toggle],
        ),
      ),
    );
    return Stack(children: [?backdrop, menu]);
  }
}

class _SingleFab extends StatelessWidget {
  const _SingleFab({required this.action});

  final FabAction action;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(_fabInset),
        child: FloatingActionButton(
          onPressed: action.onTap,
          tooltip: action.label,
          child: Icon(action.icon),
        ),
      ),
    );
  }
}

class _ActionCapsule extends StatelessWidget {
  const _ActionCapsule({required this.action, required this.onTap});

  static const _capsuleRadius = 14.0;

  static const _capsuleIconSize = 16.0;

  static const _iconLabelGap = 6.0;

  static const _capsuleLeftPadding = 11.0;

  static const _capsuleVerticalPadding = 10.0;

  static const _capsuleRightPadding = 14.0;

  final FabAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_capsuleRadius);
    final glyph = ExcludeSemantics(
      child: Icon(action.icon, size: _capsuleIconSize, color: colors.onAction),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: _iconLabelGap),
        ExcludeSemantics(child: Text(action.label)),
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(
        _capsuleLeftPadding,
        _capsuleVerticalPadding,
        _capsuleRightPadding,
        _capsuleVerticalPadding,
      ),
      child: row,
    );
    return Semantics(
      button: true,
      label: action.label,
      child: Material(
        color: colors.action,
        textStyle: TextStyle(color: colors.onAction),
        borderRadius: radius,
        child: InkWell(borderRadius: radius, onTap: onTap, child: body),
      ),
    );
  }
}
