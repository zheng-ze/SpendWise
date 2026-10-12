import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheet_alert.dart';
import 'package:spendwise/ui/common/sheet_pinned_layout.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

export 'package:spendwise/ui/common/app_sheet_route.dart';

// MARK: - Constants

const _unboundedExtent = double.infinity;

const _sheetMaxWidth = 440.0;

// MARK: - Presentation

enum AppSheetPresentation { phone, desktop }

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
    final presentation = AppSheetAlertSlot.maybeOf(context)?.presentation;
    if (presentation == null) {
      throw FlutterError(
        'AppSheet must be hosted under an AppSheetAlertSlot '
        'with an explicit presentation.',
      );
    }
    final desktop = presentation == AppSheetPresentation.desktop;
    final media = MediaQuery.of(context);
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
        : BoxConstraints(maxHeight: cap, minWidth: _unboundedExtent);
    final chrome = _SheetChrome(
      desktop: desktop,
      bottomInset: media.padding.bottom,
      child: scrollBody,
    );

    return ConstrainedBox(constraints: constraints, child: chrome);
  }
}

// MARK: - Structure

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
