import 'dart:math' as math;

import 'package:flutter/material.dart';

const _enterDuration = Duration(milliseconds: 240);

const _exitDuration = Duration(milliseconds: 200);

const _enterCurve = Curves.easeOutCubic;

const _exitCurve = Curves.easeInCubic;

const _surfaceHeight = 192.0;

const _collapsedAlignment = Alignment.topCenter;

const _hidden = 0.0;

const _shown = 1.0;

typedef InputSurfaceBuilder = Widget Function(
  BuildContext context,
  Widget surface,
  double growth,
);

class AnimatedInputSurface extends StatefulWidget {
  const AnimatedInputSurface({
    super.key,
    required this.child,
    required this.grown,
    required this.builder,
  });

  final Widget? child;

  final bool grown;

  final InputSurfaceBuilder builder;

  @override
  State<AnimatedInputSurface> createState() => _AnimatedInputSurfaceState();
}

class _AnimatedInputSurfaceState extends State<AnimatedInputSurface>
    with TickerProviderStateMixin {
  late final _surface = AnimationController(
    vsync: this,
    value: widget.child == null ? _hidden : _shown,
  )..addStatusListener(_dropWhenHidden);
  late final _growth = AnimationController(
    vsync: this,
    value: widget.grown ? _shown : _hidden,
  );
  Widget? _lastChild;

  @override
  void dispose() {
    _surface.dispose();
    _growth.dispose();
    super.dispose();
  }

  void _dropWhenHidden(AnimationStatus status) {
    final settled = status.isCompleted || status.isDismissed;
    final hidden = settled && _surface.value == _hidden;
    if (hidden && widget.child == null) setState(() => _lastChild = null);
  }

  @override
  void didUpdateWidget(AnimatedInputSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _drive(_surface, widget.child != null);
    _drive(_growth, widget.grown);
  }

  void _drive(AnimationController controller, bool entering) {
    final target = entering ? _shown : _hidden;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = target;
      return;
    }
    controller.animateTo(
      target,
      duration: entering ? _enterDuration : _exitDuration,
      curve: entering ? _enterCurve : _exitCurve,
    );
  }

  double _surfaceFactor(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final room = math.max(_hidden, _shown - inset / _surfaceHeight);
    return math.min(_surface.value, room);
  }

  @override
  Widget build(BuildContext context) {
    _lastChild = widget.child ?? _lastChild;
    return ListenableBuilder(
      listenable: Listenable.merge([_surface, _growth]),
      builder: (context, _) {
        final factor = _surfaceFactor(context);
        final slid = FractionalTranslation(
          translation: Offset(0, _shown - factor),
          child: _lastChild,
        );
        final surface = ClipRect(
          child: Align(
            alignment: _collapsedAlignment,
            heightFactor: factor,
            child: slid,
          ),
        );
        return widget.builder(context, surface, _growth.value);
      },
    );
  }
}
