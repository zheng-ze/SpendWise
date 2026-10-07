import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:spendwise/ui/common/sheet_alert.dart';
import 'package:spendwise/ui/shell/layout_breakpoints.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _sheetMaxWidth = 440.0;

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(AppSheetRoute<T>(builder: builder));
}

class AppSheetAlertSlot extends InheritedWidget {
  const AppSheetAlertSlot({
    super.key,
    required this.alerts,
    required this.alertAction,
    required super.child,
  });

  final ValueNotifier<SheetAlertData?> alerts;

  final ValueNotifier<VoidCallback?> alertAction;

  static AppSheetAlertSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSheetAlertSlot>();

  @override
  bool updateShouldNotify(covariant AppSheetAlertSlot oldWidget) =>
      alerts != oldWidget.alerts || alertAction != oldWidget.alertAction;
}

class AppSheet extends StatefulWidget {
  const AppSheet({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.inputSurface,
    this.alert,
    this.onAlertAction,
  });

  final Widget header;

  final Widget body;

  final Widget? footer;

  final Widget? inputSurface;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  @override
  State<AppSheet> createState() => _AppSheetState();
}

class _AppSheetState extends State<AppSheet> {
  static const _maxHeightFraction = 0.66;

  ValueNotifier<SheetAlertData?>? _alerts;

  ValueNotifier<VoidCallback?>? _alertAction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final slot = AppSheetAlertSlot.maybeOf(context);
    _alerts = slot?.alerts;
    _alertAction = slot?.alertAction;
    _publishAlert();
  }

  @override
  void didUpdateWidget(covariant AppSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alert != widget.alert ||
        oldWidget.onAlertAction != widget.onAlertAction) {
      _publishAlert();
    }
  }

  @override
  void dispose() {
    _alerts?.value = null;
    _alertAction?.value = null;
    super.dispose();
  }

  void _publishAlert() {
    final alerts = _alerts;
    final alertAction = _alertAction;
    if (alerts == null || alertAction == null) return;
    final data = widget.alert;
    final action = widget.onAlertAction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      alerts.value = data;
      alertAction.value = action;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final desktop = media.size.width >= LayoutBreakpoints.railEnter;
    final cap =
        _maxHeightFraction *
        (media.size.height - media.padding.top - media.viewInsets.bottom);
    final hasBottom = widget.footer != null || widget.inputSurface != null;
    final top = _SheetTop(header: widget.header);
    final bottom = hasBottom
        ? _SheetBottom(footer: widget.footer, inputSurface: widget.inputSurface)
        : null;
    final scrollBody = _SheetScrollBody(
      top: top,
      body: widget.body,
      bottom: bottom,
    );
    final constraints = desktop
        ? BoxConstraints(maxHeight: cap, maxWidth: _sheetMaxWidth)
        : BoxConstraints(maxHeight: cap, minWidth: double.infinity);
    final chrome = _SheetChrome(
      desktop: desktop,
      bottomInset: media.padding.bottom,
      child: scrollBody,
    );

    return ConstrainedBox(constraints: constraints, child: chrome);
  }
}

class _SheetTop extends StatelessWidget {
  const _SheetTop({required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const _SheetHandle(), header],
    );
  }
}

class _SheetBottom extends StatelessWidget {
  const _SheetBottom({required this.footer, required this.inputSurface});

  final Widget? footer;

  final Widget? inputSurface;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [?footer, ?inputSurface],
    );
  }
}

class _SheetScrollBody extends StatelessWidget {
  const _SheetScrollBody({
    required this.top,
    required this.body,
    required this.bottom,
  });

  final Widget top;

  final Widget body;

  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: _SheetLayout(
          maxHeight: constraints.maxHeight,
          top: top,
          body: SingleChildScrollView(child: body),
          bottom: bottom,
        ),
      ),
    );
  }
}

class _SheetChrome extends StatelessWidget {
  const _SheetChrome({
    required this.desktop,
    required this.bottomInset,
    required this.child,
  });

  static const _desktopRadius = 16.0;

  static const _sheetTopRadius = 22.0;

  static const _topBorderWidth = 2.0;

  static const _horizontalPadding = 14.0;

  static const _topPadding = 8.0;

  static const _bottomPadding = 14.0;

  final bool desktop;

  final double bottomInset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = desktop
        ? BorderRadius.circular(_desktopRadius)
        : const BorderRadius.vertical(top: Radius.circular(_sheetTopRadius));
    final border = desktop
        ? Border.all(color: colors.control)
        : Border(
            top: BorderSide(color: colors.control, width: _topBorderWidth),
          );
    final decoration = BoxDecoration(border: border, borderRadius: radius);
    final padding = EdgeInsets.fromLTRB(
      _horizontalPadding,
      _topPadding,
      _horizontalPadding,
      _bottomPadding + bottomInset,
    );

    return Material(
      color: colors.raised,
      borderRadius: radius,
      child: Container(decoration: decoration, padding: padding, child: child),
    );
  }
}

enum _SheetSlot { top, body, bottom }

// Keeps top and bottom pinned while only the body scrolls. When top and
// bottom alone exceed maxHeight, the body takes its natural height so the
// enclosing scroll view scrolls the whole sheet and every control stays
// reachable.
class _SheetLayout
    extends SlottedMultiChildRenderObjectWidget<_SheetSlot, RenderBox> {
  const _SheetLayout({
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
  Iterable<_SheetSlot> get slots => _SheetSlot.values;

  @override
  Widget? childForSlot(_SheetSlot slot) => switch (slot) {
    _SheetSlot.top => top,
    _SheetSlot.body => body,
    _SheetSlot.bottom => bottom,
  };

  @override
  _RenderSheetLayout createRenderObject(BuildContext context) =>
      _RenderSheetLayout(maxHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSheetLayout renderObject,
  ) {
    renderObject.maxHeight = maxHeight;
  }
}

class _RenderSheetLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_SheetSlot, RenderBox> {
  _RenderSheetLayout(this._maxHeight);

  double _maxHeight;

  set maxHeight(double value) {
    if (value == _maxHeight) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final top = childForSlot(_SheetSlot.top)!;
    final body = childForSlot(_SheetSlot.body)!;
    final bottom = childForSlot(_SheetSlot.bottom);

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
    return top.size.height + (bottom?.size.height ?? 0);
  }

  void _layoutBody(
    BoxConstraints childConstraints,
    RenderBox body,
    double pinnedHeight,
  ) {
    final bodyMaxHeight = pinnedHeight <= _maxHeight
        ? _maxHeight - pinnedHeight
        : double.infinity;
    body.layout(
      childConstraints.copyWith(maxHeight: bodyMaxHeight),
      parentUsesSize: true,
    );
  }

  double _widestChild(List<RenderBox> ordered) {
    var widest = 0.0;
    for (final child in ordered) {
      if (child.size.width > widest) widest = child.size.width;
    }
    return widest;
  }

  double _positionChildren(List<RenderBox> ordered, double width) {
    var y = 0.0;
    for (final child in ordered) {
      (child.parentData! as BoxParentData).offset = Offset(
        (width - child.size.width) / 2,
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  static const _handleWidth = 34.0;

  static const _handleHeight = 4.0;

  static const _handleBottomMargin = 8.0;

  static const _handleRadius = 3.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _handleWidth,
      height: _handleHeight,
      margin: const EdgeInsets.only(bottom: _handleBottomMargin),
      decoration: BoxDecoration(
        color: context.colors.control,
        borderRadius: BorderRadius.circular(_handleRadius),
      ),
    );
  }
}

class AppSheetRoute<T> extends ModalRoute<T> {
  AppSheetRoute({required this.builder});

  static const _transitionMillis = 220;

  static const _transitionDuration = Duration(milliseconds: _transitionMillis);

  static const _barrierColor = Color(0x52101212);

  static const _slideBeginDy = 0.06;

  final WidgetBuilder builder;

  late final ValueNotifier<SheetAlertData?> _alerts =
      ValueNotifier<SheetAlertData?>(null);

  late final ValueNotifier<VoidCallback?> _alertAction =
      ValueNotifier<VoidCallback?>(null);

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AppSheetAlertSlot(
      alerts: _alerts,
      alertAction: _alertAction,
      child: _AppSheetPage(builder: builder),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(0, _slideBeginDy),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  void dispose() {
    _alerts.dispose();
    _alertAction.dispose();
    super.dispose();
  }
}

class _AppSheetPage extends StatelessWidget {
  const _AppSheetPage({required this.builder});

  static const _desktopAlertTop = 16.0;

  static const _compactAlertTop = 12.0;

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final desktop = media.size.width >= LayoutBreakpoints.railEnter;
    final sheet = Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Builder(builder: builder),
    );
    final positionedSheet = desktop
        ? Center(child: sheet)
        : Align(alignment: Alignment.bottomCenter, child: sheet);
    final slot = AppSheetAlertSlot.maybeOf(context);
    if (slot == null) return positionedSheet;
    final alertTop =
        media.padding.top + (desktop ? _desktopAlertTop : _compactAlertTop);
    final overlay = _SheetAlertOverlay(slot: slot, alertTop: alertTop);

    return Stack(children: [positionedSheet, overlay]);
  }
}

class _SheetAlertOverlay extends StatelessWidget {
  const _SheetAlertOverlay({required this.slot, required this.alertTop});

  static const _overlayHorizontalInset = 12.0;

  final AppSheetAlertSlot slot;

  final double alertTop;

  @override
  Widget build(BuildContext context) {
    final banner = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
      child: _SheetAlertListener(slot: slot),
    );

    return Positioned(
      top: alertTop,
      left: _overlayHorizontalInset,
      right: _overlayHorizontalInset,
      child: Center(child: banner),
    );
  }
}

class _SheetAlertListener extends StatelessWidget {
  const _SheetAlertListener({required this.slot});

  final AppSheetAlertSlot slot;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SheetAlertData?>(
      valueListenable: slot.alerts,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _SheetAlertActionListener(slot: slot, data: data);
      },
    );
  }
}

class _SheetAlertActionListener extends StatelessWidget {
  const _SheetAlertActionListener({required this.slot, required this.data});

  final AppSheetAlertSlot slot;

  final SheetAlertData data;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VoidCallback?>(
      valueListenable: slot.alertAction,
      builder: (context, action, _) => SheetAlert(data: data, onAction: action),
    );
  }
}
