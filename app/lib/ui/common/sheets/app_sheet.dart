import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/common/sheets/sheet_drag_dismiss.dart';
import 'package:spendwise/ui/common/sheets/sheet_pinned_layout.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

export 'package:spendwise/ui/common/sheets/app_sheet_route.dart';

// MARK: - Constants

const _unboundedExtent = double.infinity;

const _sheetMaxWidth = 440.0;

const _formDesktopWidth = 340.0;

// MARK: - Presentation

enum AppSheetPresentation { phone, open, desktop }

enum AppSheetVariant { standard, form }

// MARK: - Alert Slot

class AppSheetAlertSlot extends InheritedWidget {
  const AppSheetAlertSlot({
    super.key,
    required this.presentation,
    required this.alerts,
    required this.alertAction,
    required super.child,
  });

  final AppSheetPresentation presentation;

  final ValueNotifier<SheetAlertData?> alerts;

  final ValueNotifier<VoidCallback?> alertAction;

  static AppSheetAlertSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSheetAlertSlot>();

  @override
  bool updateShouldNotify(covariant AppSheetAlertSlot oldWidget) =>
      presentation != oldWidget.presentation ||
      alerts != oldWidget.alerts ||
      alertAction != oldWidget.alertAction;
}

// MARK: - Sheet

class AppSheet extends StatefulWidget {
  const AppSheet({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.inputSurface,
    this.alert,
    this.onAlertAction,
    this.desktopMaxHeightFraction = defaultMaxHeightFraction,
    this.phoneMaxHeightFraction = defaultMaxHeightFraction,
    this.dragToDismiss = false,
    this.variant = AppSheetVariant.standard,
  });

  static const defaultMaxHeightFraction = 0.66;

  final Widget header;

  final Widget body;

  final Widget? footer;

  final Widget? inputSurface;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  final double desktopMaxHeightFraction;

  final double phoneMaxHeightFraction;

  final bool dragToDismiss;

  final AppSheetVariant variant;

  @override
  State<AppSheet> createState() => _AppSheetState();
}

class _AppSheetState extends State<AppSheet> {
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

  void _dismiss() => Navigator.of(context).maybePop();

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
    final presentation = AppSheetAlertSlot.maybeOf(context)?.presentation;
    if (presentation == null) {
      throw FlutterError(
        'AppSheet must be hosted under an AppSheetAlertSlot '
        'with an explicit presentation.',
      );
    }
    final open = presentation == AppSheetPresentation.open;
    final desktop = presentation == AppSheetPresentation.desktop;
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.padding.top - media.viewInsets.bottom;
    final cap =
        (desktop
            ? widget.desktopMaxHeightFraction
            : widget.phoneMaxHeightFraction) *
        available;
    final openHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        media.viewInsets.bottom;
    final hasBottom = widget.footer != null || widget.inputSurface != null;
    final phone = presentation == AppSheetPresentation.phone;
    final form = widget.variant == AppSheetVariant.form;
    final showHandle = !open && !(desktop && form);
    final top = _SheetTop(header: widget.header, showHandle: showHandle);
    final bottom = hasBottom
        ? _SheetBottom(footer: widget.footer, inputSurface: widget.inputSurface)
        : null;
    final scrollBody = _SheetScrollBody(
      top: top,
      body: widget.body,
      bottom: bottom,
    );
    final constraints = open
        ? BoxConstraints(minHeight: openHeight, maxHeight: openHeight)
        : desktop
        ? BoxConstraints(
            maxHeight: cap,
            minWidth: form ? _formDesktopWidth : 0,
            maxWidth: form ? _formDesktopWidth : _sheetMaxWidth,
          )
        : BoxConstraints(maxHeight: cap, minWidth: _unboundedExtent);
    final chrome = _SheetChrome(
      presentation: presentation,
      variant: widget.variant,
      bottomInset: media.padding.bottom,
      child: scrollBody,
    );
    final sheet = ConstrainedBox(constraints: constraints, child: chrome);
    if (!widget.dragToDismiss) return sheet;

    return SheetDragDismiss(enabled: phone, onDismiss: _dismiss, child: sheet);
  }
}

// MARK: - Structure

class _SheetTop extends StatelessWidget {
  const _SheetTop({required this.header, required this.showHandle});

  final Widget header;

  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [if (showHandle) const _SheetHandle(), header],
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
    final handle = SheetDragScope.maybeOf(context);
    final bodyPhysics = handle == null
        ? null
        : SheetDismissPhysics(handle: handle);
    final sheetPhysics = handle == null
        ? null
        : SheetDismissPhysics(
            parent: const AlwaysScrollableScrollPhysics(),
            handle: handle,
          );
    final scrollingBody = SingleChildScrollView(
      physics: bodyPhysics,
      child: body,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: sheetPhysics,
        child: SheetPinnedLayout(
          maxHeight: constraints.maxHeight,
          top: top,
          body: scrollingBody,
          bottom: bottom,
        ),
      ),
    );
  }
}

// MARK: - Chrome

class _SheetChrome extends StatelessWidget {
  const _SheetChrome({
    required this.presentation,
    required this.variant,
    required this.bottomInset,
    required this.child,
  });

  static const _formDesktopRadius = 18.0;

  static const _formDesktopPadding = EdgeInsets.symmetric(
    vertical: 16.0,
    horizontal: 18.0,
  );

  static const _formTopBorderWidth = 1.0;

  static const _formShadow = BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, -8),
    blurRadius: 22.0,
  );

  static const _desktopRadius = 16.0;

  static const _sheetTopRadius = 22.0;

  static const _topBorderWidth = 2.0;

  static const _openBorderWidth = 1.0;

  static const _horizontalPadding = 14.0;

  static const _topPadding = 8.0;

  static const _bottomPadding = 14.0;

  static const _openTopPadding = 16.0;

  static const _openRightInset = 82.0;

  static const _formOpenContentRightInset = 10.0;

  static const _openBottomPadding = 14.0;

  static const _openLeftPadding = 16.0;

  final AppSheetPresentation presentation;

  final AppSheetVariant variant;

  final double bottomInset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final open = presentation == AppSheetPresentation.open;
    final desktop = presentation == AppSheetPresentation.desktop;
    final form = variant == AppSheetVariant.form;
    final canvas = form && Theme.of(context).brightness == Brightness.light;
    final desktopRadius = form ? _formDesktopRadius : _desktopRadius;
    final topBorder = canvas
        ? BorderSide(color: colors.edge, width: _formTopBorderWidth)
        : BorderSide(color: colors.control, width: _topBorderWidth);
    final radius = open
        ? BorderRadius.zero
        : desktop
        ? BorderRadius.circular(desktopRadius)
        : const BorderRadius.vertical(top: Radius.circular(_sheetTopRadius));
    final border = open
        ? Border(
            left: BorderSide(color: colors.control, width: _openBorderWidth),
          )
        : desktop
        ? Border.all(color: colors.control)
        : Border(top: topBorder);
    final shadow = canvas && !open && !desktop ? [_formShadow] : null;
    final decoration = BoxDecoration(
      color: canvas ? colors.base : null,
      border: border,
      borderRadius: radius,
      boxShadow: shadow,
    );
    final clearsRail = open && form;
    final contentRightInset = clearsRail
        ? _formOpenContentRightInset
        : _openRightInset;
    final railClearance = EdgeInsets.only(
      right: clearsRail ? _openRightInset : 0,
    );
    final padding = form && desktop
        ? _formDesktopPadding.add(EdgeInsets.only(bottom: bottomInset))
        : open
        ? EdgeInsets.fromLTRB(
            _openLeftPadding,
            _openTopPadding,
            contentRightInset,
            _openBottomPadding + bottomInset,
          )
        : EdgeInsets.fromLTRB(
            _horizontalPadding,
            _topPadding,
            _horizontalPadding,
            _bottomPadding + bottomInset,
          );

    final surface = Material(
      color: canvas ? colors.base : colors.raised,
      borderRadius: radius,
      child: Container(decoration: decoration, padding: padding, child: child),
    );
    return Padding(padding: railClearance, child: surface);
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
