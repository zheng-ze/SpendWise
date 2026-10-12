import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/app_sheet.dart';
import 'package:spendwise/ui/common/sheet_alert.dart';

// MARK: - Constants

const _paintOrigin = Offset.zero;

// MARK: - Show

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required AppSheetPresentation presentation,
  required WidgetBuilder builder,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(AppSheetRoute<T>(presentation: presentation, builder: builder));
}

// MARK: - Route

class AppSheetRoute<T> extends ModalRoute<T> {
  AppSheetRoute({required this.presentation, required this.builder});

  static const _transitionMillis = 220;

  static const _transitionDuration = Duration(milliseconds: _transitionMillis);

  static const _barrierColor = Color(0x52101212);

  static const _slideBeginDy = 0.06;

  static const _slideBegin = Offset(0, _slideBeginDy);

  final WidgetBuilder builder;

  final AppSheetPresentation presentation;

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
      presentation: presentation,
      alerts: _alerts,
      alertAction: _alertAction,
      child: _AppSheetPage(presentation: presentation, builder: builder),
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
      begin: _slideBegin,
      end: _paintOrigin,
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

// MARK: - Page

class _AppSheetPage extends StatelessWidget {
  const _AppSheetPage({required this.presentation, required this.builder});

  static const _desktopAlertTop = 16.0;

  static const _compactAlertTop = 12.0;

  static const _bottomAlignment = Alignment.bottomCenter;

  final AppSheetPresentation presentation;

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final desktop = presentation == AppSheetPresentation.desktop;
    final sheet = Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Builder(builder: builder),
    );
    final positionedSheet = desktop
        ? Center(child: sheet)
        : Align(alignment: _bottomAlignment, child: sheet);
    final slot = AppSheetAlertSlot.maybeOf(context);
    if (slot == null) return positionedSheet;
    final alertTop =
        media.padding.top + (desktop ? _desktopAlertTop : _compactAlertTop);
    final overlay = _SheetAlertOverlay(slot: slot, alertTop: alertTop);

    return Stack(children: [positionedSheet, overlay]);
  }
}

// MARK: - Alert Overlay

class _SheetAlertOverlay extends StatelessWidget {
  const _SheetAlertOverlay({required this.slot, required this.alertTop});

  static const _overlayHorizontalInset = 12.0;

  static const _sheetMaxWidth = 440.0;

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
