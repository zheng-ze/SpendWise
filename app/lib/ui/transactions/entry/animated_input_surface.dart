import 'package:flutter/material.dart';

const _enterDuration = Duration(milliseconds: 240);

const _exitDuration = Duration(milliseconds: 200);

const _enterCurve = Curves.easeOutCubic;

const _exitCurve = Curves.easeInCubic;

const _slideFrom = Offset(0, 1);

const _collapsedAlignment = Alignment.topCenter;

const _hidden = 0.0;

const _shown = 1.0;

class AnimatedInputSurface extends StatefulWidget {
  const AnimatedInputSurface({
    super.key,
    required this.child,
    required this.instant,
  });

  final Widget? child;

  final bool instant;

  @override
  State<AnimatedInputSurface> createState() => _AnimatedInputSurfaceState();
}

class _AnimatedInputSurfaceState extends State<AnimatedInputSurface>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.child == null ? _hidden : _shown,
  )..addStatusListener(_dropWhenHidden);
  Widget? _lastChild;

  void _dropWhenHidden(AnimationStatus status) {
    final settled = status.isCompleted || status.isDismissed;
    final hidden = settled && _controller.value == _hidden;
    if (hidden && widget.child == null) setState(() => _lastChild = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedInputSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entering = widget.child != null;
    final target = entering ? _shown : _hidden;
    final still = MediaQuery.disableAnimationsOf(context);
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final immediate = widget.instant || still || keyboardUp;
    if (immediate) {
      _controller.value = target;
      return;
    }
    _controller.animateTo(
      target,
      duration: entering ? _enterDuration : _exitDuration,
      curve: entering ? _enterCurve : _exitCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    _lastChild = widget.child ?? _lastChild;
    final slide = Tween<Offset>(
      begin: _slideFrom,
      end: Offset.zero,
    ).animate(_controller);
    final content = SlideTransition(position: slide, child: _lastChild);

    return SizeTransition(
      sizeFactor: _controller,
      alignment: _collapsedAlignment,
      child: content,
    );
  }
}
