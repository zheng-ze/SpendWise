import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// MARK: - Constants

const _unboundedExtent = double.infinity;

const _emptyExtent = 0.0;

const _centerDivisor = 2.0;

// MARK: - Slot

enum SheetPinnedSlot { top, body, bottom }

// MARK: - Layout Widget

// Keeps top and bottom pinned while only the body scrolls. When top and
// bottom alone exceed maxHeight, the body takes its natural height so the
// enclosing scroll view scrolls the whole sheet and every control stays
// reachable.
class SheetPinnedLayout
    extends SlottedMultiChildRenderObjectWidget<SheetPinnedSlot, RenderBox> {
  const SheetPinnedLayout({
    super.key,
    required this.maxHeight,
    required this.top,
    required this.body,
    required this.bottom,
  });

  final double maxHeight;

  final Widget top;

  final Widget body;

  final Widget? bottom;

  @override
  Iterable<SheetPinnedSlot> get slots => SheetPinnedSlot.values;

  @override
  Widget? childForSlot(SheetPinnedSlot slot) => switch (slot) {
    SheetPinnedSlot.top => top,
    SheetPinnedSlot.body => body,
    SheetPinnedSlot.bottom => bottom,
  };

  @override
  SlottedContainerRenderObjectMixin<SheetPinnedSlot, RenderBox>
  createRenderObject(BuildContext context) =>
      _SheetPinnedRenderLayout(maxHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    SlottedContainerRenderObjectMixin<SheetPinnedSlot, RenderBox> renderObject,
  ) {
    (renderObject as _SheetPinnedRenderLayout).maxHeight = maxHeight;
  }
}

// MARK: - Render Object

class _SheetPinnedRenderLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<SheetPinnedSlot, RenderBox> {
  _SheetPinnedRenderLayout(this._maxHeight);

  double _maxHeight;

  set maxHeight(double value) {
    if (value == _maxHeight) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final top = childForSlot(SheetPinnedSlot.top)!;
    final body = childForSlot(SheetPinnedSlot.body)!;
    final bottom = childForSlot(SheetPinnedSlot.bottom);

    final pinnedHeight = _layoutPinned(childConstraints, top, bottom);
    _layoutBody(childConstraints, body, pinnedHeight);
    final ordered = [top, body, ?bottom];
    final width = constraints.constrainWidth(_widestChild(ordered));
    final height = _positionChildren(ordered, width);
    size = constraints.constrain(Size(width, height));
  }

  double _layoutPinned(
    BoxConstraints childConstraints,
    RenderBox top,
    RenderBox? bottom,
  ) {
    top.layout(childConstraints, parentUsesSize: true);
    bottom?.layout(childConstraints, parentUsesSize: true);
    return top.size.height + (bottom?.size.height ?? _emptyExtent);
  }

  void _layoutBody(
    BoxConstraints childConstraints,
    RenderBox body,
    double pinnedHeight,
  ) {
    final bodyMaxHeight = pinnedHeight <= _maxHeight
        ? _maxHeight - pinnedHeight
        : _unboundedExtent;
    body.layout(
      childConstraints.copyWith(maxHeight: bodyMaxHeight),
      parentUsesSize: true,
    );
  }

  double _widestChild(List<RenderBox> ordered) {
    var widest = _emptyExtent;
    for (final child in ordered) {
      if (child.size.width > widest) widest = child.size.width;
    }
    return widest;
  }

  double _positionChildren(List<RenderBox> ordered, double width) {
    var y = _emptyExtent;
    for (final child in ordered) {
      (child.parentData! as BoxParentData).offset = Offset(
        (width - child.size.width) / _centerDivisor,
        y,
      );
      y += child.size.height;
    }
    return y;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
