import 'dart:math' as math;

import 'package:flutter/material.dart';

const _dismissFraction = 0.25;

const _flingVelocity = 700.0;

const _springBackDuration = Duration(milliseconds: 200);

const _springBackCurve = Curves.easeOut;

const _noOffset = 0.0;

class SheetDragHandle {
  const SheetDragHandle({required this.offset, required this.update});

  final double Function() offset;

  final ValueChanged<double> update;
}

class SheetDismissPhysics extends ClampingScrollPhysics {
  const SheetDismissPhysics({super.parent, required this.handle});

  final SheetDragHandle handle;

  @override
  SheetDismissPhysics applyTo(ScrollPhysics? ancestor) =>
      SheetDismissPhysics(parent: buildParent(ancestor), handle: handle);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis != Axis.vertical) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    if (offset > _noOffset) return _scrollOrDrag(position, offset);
    final reclaimed = math.min(-offset, handle.offset());
    if (reclaimed > _noOffset) handle.update(-reclaimed);
    return offset + reclaimed;
  }

  double _scrollOrDrag(ScrollMetrics position, double offset) {
    final room = math.max(
      _noOffset,
      position.pixels - position.minScrollExtent,
    );
    final scrolled = math.min(offset, room);
    final dragged = offset - scrolled;
    if (dragged > _noOffset) handle.update(dragged);
    return scrolled;
  }
}

class SheetDragScope extends InheritedWidget {
  const SheetDragScope({super.key, required this.handle, required super.child});

  final SheetDragHandle? handle;

  static SheetDragHandle? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SheetDragScope>()?.handle;

  @override
  bool updateShouldNotify(SheetDragScope oldWidget) => false;
}

class SheetDismissScrollConfiguration extends StatelessWidget {
  const SheetDismissScrollConfiguration({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final handle = SheetDragScope.maybeOf(context);
    if (handle == null) return child;
    final behavior = ScrollConfiguration.of(context)
        .copyWith(physics: SheetDismissPhysics(handle: handle));

    return ScrollConfiguration(behavior: behavior, child: child);
  }
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
  void didUpdateWidget(SheetDragDismiss oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled) return;
    _spring.stop();
    _offset = _noOffset;
  }

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
    if (_offset == _noOffset) return;
    if (velocity > _flingVelocity) return widget.onDismiss();
    final height = context.size?.height ?? _noOffset;
    if (_offset > height * _dismissFraction) return widget.onDismiss();
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _offset = _noOffset);
      return;
    }
    _springFrom = _offset;
    _spring.forward(from: _noOffset);
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    _end(notification.dragDetails?.primaryVelocity ?? _noOffset);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final handle = SheetDragHandle(offset: () => _offset, update: _update);
    final shifted = Transform.translate(
      offset: Offset(_noOffset, _offset),
      child: widget.child,
    );
    final listener = NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: shifted,
    );

    return SheetDragScope(
      handle: widget.enabled ? handle : null,
      child: listener,
    );
  }
}
