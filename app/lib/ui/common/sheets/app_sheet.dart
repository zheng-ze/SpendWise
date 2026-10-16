import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/common/sheets/sheet_pinned_layout.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

export 'package:spendwise/ui/common/sheets/app_sheet_route.dart';

// MARK: - Constants

const _unboundedExtent = double.infinity;

const _sheetMaxWidth = 440.0;

// MARK: - Presentation

enum AppSheetPresentation { phone, open, desktop }

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
  });

  static const defaultMaxHeightFraction = 0.66;

  final Widget header;

  final Widget body;

  final Widget? footer;

  final Widget? inputSurface;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  final double desktopMaxHeightFraction;

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
            : AppSheet.defaultMaxHeightFraction) *
        available;
    final openHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        media.viewInsets.bottom;
    final hasBottom = widget.footer != null || widget.inputSurface != null;
    final top = _SheetTop(header: widget.header, showHandle: !open);
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
        ? BoxConstraints(maxHeight: cap, maxWidth: _sheetMaxWidth)
        : BoxConstraints(maxHeight: cap, minWidth: _unboundedExtent);
    final chrome = _SheetChrome(
      presentation: presentation,
      bottomInset: media.padding.bottom,
      child: scrollBody,
    );

    return ConstrainedBox(constraints: constraints, child: chrome);
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SheetPinnedLayout(
          maxHeight: constraints.maxHeight,
          top: top,
          body: SingleChildScrollView(child: body),
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
    required this.bottomInset,
    required this.child,
  });

  static const _desktopRadius = 16.0;

  static const _sheetTopRadius = 22.0;

  static const _topBorderWidth = 2.0;

  static const _openBorderWidth = 1.0;

  static const _horizontalPadding = 14.0;

  static const _topPadding = 8.0;

  static const _bottomPadding = 14.0;

  static const _openTopPadding = 16.0;

  static const _openRightInset = 82.0;

  static const _openBottomPadding = 14.0;

  static const _openLeftPadding = 16.0;

  final AppSheetPresentation presentation;

  final double bottomInset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final open = presentation == AppSheetPresentation.open;
    final desktop = presentation == AppSheetPresentation.desktop;
    final radius = open
        ? BorderRadius.zero
        : desktop
        ? BorderRadius.circular(_desktopRadius)
        : const BorderRadius.vertical(top: Radius.circular(_sheetTopRadius));
    final border = open
        ? Border(
            left: BorderSide(color: colors.control, width: _openBorderWidth),
          )
        : desktop
        ? Border.all(color: colors.control)
        : Border(
            top: BorderSide(color: colors.control, width: _topBorderWidth),
          );
    final decoration = BoxDecoration(border: border, borderRadius: radius);
    final padding = open
        ? EdgeInsets.fromLTRB(
            _openLeftPadding,
            _openTopPadding,
            _openRightInset,
            _openBottomPadding + bottomInset,
          )
        : EdgeInsets.fromLTRB(
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
