import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:spendwise/ui/overview/overview_grid_placement.dart';

class OverviewWaterfallParentData extends ContainerBoxParentData<RenderBox> {
  int span = 1;
}

class OverviewWaterfallSlot
    extends ParentDataWidget<OverviewWaterfallParentData> {
  const OverviewWaterfallSlot({
    super.key,
    required this.span,
    required super.child,
  });

  final int span;

  @override
  Type get debugTypicalAncestorWidgetClass => OverviewWaterfall;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as OverviewWaterfallParentData;
    if (parentData.span == span) {
      return;
    }
    parentData.span = span;
    renderObject.parent?.markNeedsLayout();
  }
}

class OverviewWaterfall extends MultiChildRenderObjectWidget {
  const OverviewWaterfall({
    super.key,
    required this.columnCount,
    required this.gap,
    required super.children,
  });

  final int columnCount;
  final double gap;

  @override
  RenderOverviewWaterfall createRenderObject(BuildContext context) =>
      RenderOverviewWaterfall(columnCount: columnCount, gap: gap);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderOverviewWaterfall renderObject,
  ) {
    renderObject
      ..columnCount = columnCount
      ..gap = gap;
  }
}

class RenderOverviewWaterfall extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, OverviewWaterfallParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          OverviewWaterfallParentData
        > {
  RenderOverviewWaterfall({required this._columnCount, required this._gap});

  int _columnCount;
  int get columnCount => _columnCount;
  set columnCount(int value) {
    if (value == _columnCount) {
      return;
    }
    _columnCount = value;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) {
      return;
    }
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! OverviewWaterfallParentData) {
      child.parentData = OverviewWaterfallParentData();
    }
  }

  double _columnWidth(double maxWidth) =>
      (maxWidth - _gap * (_columnCount - 1)) / _columnCount;

  BoxConstraints _childConstraints(double columnWidth, int span) {
    final clampedSpan = math.min(span, _columnCount);
    final width = columnWidth * clampedSpan + _gap * (clampedSpan - 1);
    return BoxConstraints(minWidth: width, maxWidth: width);
  }

  Size _arrange(
    BoxConstraints constraints, {
    required Size Function(RenderBox child, BoxConstraints constraints) measure,
    void Function(RenderBox child, Offset offset)? position,
  }) {
    final maxWidth = constraints.maxWidth;
    final columnWidth = _columnWidth(maxWidth);
    final columns = OverviewWaterfallColumns(
      columnCount: _columnCount,
      gap: _gap,
    );
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as OverviewWaterfallParentData;
      final span = math.min(parentData.span, _columnCount);
      final size = measure(child, _childConstraints(columnWidth, span));
      final placement = columns.place(span: span, height: size.height);
      position?.call(
        child,
        Offset(placement.column * (columnWidth + _gap), placement.top),
      );
      child = parentData.nextSibling;
    }
    final height = columns.height;
    return constraints.constrain(Size(maxWidth, height));
  }

  @override
  void performLayout() {
    size = _arrange(
      constraints,
      measure: (child, childConstraints) {
        child.layout(childConstraints, parentUsesSize: true);
        return child.size;
      },
      position: (child, offset) {
        (child.parentData! as OverviewWaterfallParentData).offset = offset;
      },
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _arrange(
    constraints,
    measure: (child, childConstraints) => child.getDryLayout(childConstraints),
  );

  @override
  double computeMinIntrinsicWidth(double height) => _unsupportedIntrinsics();

  @override
  double computeMaxIntrinsicWidth(double height) => _unsupportedIntrinsics();

  @override
  double computeMinIntrinsicHeight(double width) => _unsupportedIntrinsics();

  @override
  double computeMaxIntrinsicHeight(double width) => _unsupportedIntrinsics();

  Never _unsupportedIntrinsics() => throw FlutterError(
    'RenderOverviewWaterfall does not support intrinsic sizes because card '
    'placement depends on the width the parent gives it.',
  );

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
