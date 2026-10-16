import 'dart:math' as math;

import 'package:flutter/material.dart';

const _dismissFraction = 0.25;

const _flingVelocity = 700.0;

const _springBackDuration = Duration(milliseconds: 200);

const _springBackCurve = Curves.easeOut;

const _noOffset = 0.0;

class SheetDragHandle {
  const SheetDragHandle({required this.update, required this.end});

  final ValueChanged<double> update;

  final ValueChanged<double> end;
}

class SheetDragScope extends InheritedWidget {
  const SheetDragScope({super.key, required this.handle, required super.child});

  final SheetDragHandle? handle;

  static SheetDragHandle? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SheetDragScope>()?.handle;

  @override
  bool updateShouldNotify(SheetDragScope oldWidget) => false;
}

class SheetDragDismiss extends StatefulWidget {
  const SheetDragDismiss({
    super.key,
    required this.enabled,
    required this.onDismiss,
    required this.child,
  });

  final bool enabled;

  final VoidCallback onDismiss;

  final Widget child;

  @override
  State<SheetDragDismiss> createState() => _SheetDragDismissState();
}

class _SheetDragDismissState extends State<SheetDragDismiss>
    with SingleTickerProviderStateMixin {
  late final _spring = AnimationController(
    vsync: this,
    duration: _springBackDuration,
  )..addListener(_onSpring);
  double _offset = _noOffset;
  double _springFrom = _noOffset;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _onSpring() {
    final progress = _springBackCurve.transform(_spring.value);
    setState(() => _offset = _springFrom * (1 - progress));
  }

  void _update(double delta) {
    _spring.stop();
    setState(() => _offset = math.max(_noOffset, _offset + delta));
  }

  void _end(double velocity) {
    if (velocity > _flingVelocity) return widget.onDismiss();
    if (_offset == _noOffset) return;
    final height = context.size?.height ?? _noOffset;
    if (_offset > height * _dismissFraction) return widget.onDismiss();
    _springFrom = _offset;
    _spring.forward(from: _noOffset);
  }

  @override
  Widget build(BuildContext context) {
    final handle = SheetDragHandle(update: _update, end: _end);
    final shifted = Transform.translate(
      offset: Offset(_noOffset, _offset),
      child: widget.child,
    );

    return SheetDragScope(
      handle: widget.enabled ? handle : null,
      child: shifted,
    );
  }
}

class SheetBodyDrag extends StatefulWidget {
  const SheetBodyDrag({super.key, required this.handle, required this.child});

  final SheetDragHandle? handle;

  final Widget child;

  @override
  State<SheetBodyDrag> createState() => _SheetBodyDragState();
}

class _SheetBodyDragState extends State<SheetBodyDrag> {
  bool _startedAtTop = false;

  bool _onScroll(ScrollNotification notification) {
    final handle = widget.handle;
    if (handle == null) return false;
    final metrics = notification.metrics;
    if (notification is ScrollStartNotification) {
      _startedAtTop = metrics.pixels <= metrics.minScrollExtent;
    }
    if (!_startedAtTop) return false;
    if (notification is OverscrollNotification) {
      final dragging = notification.dragDetails != null;
      if (dragging && notification.overscroll < 0) {
        handle.update(-notification.overscroll);
      }
    }
    if (notification is ScrollUpdateNotification) {
      handle.update(-(notification.scrollDelta ?? _noOffset));
    }
    if (notification is ScrollEndNotification) {
      _startedAtTop = false;
      handle.end(notification.dragDetails?.primaryVelocity ?? _noOffset);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }
}
