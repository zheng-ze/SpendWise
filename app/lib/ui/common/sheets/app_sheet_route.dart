import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

// MARK: - Constants

const _paintOrigin = Offset.zero;

// MARK: - Show

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required AppSheetPresentation presentation,
  AppSheetPresentation Function(BuildContext)? presentationResolver,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    AppSheetRoute<T>(
      presentation: presentation,
      presentationResolver: presentationResolver,
      builder: builder,
    ),
  );
}

// MARK: - Route

class AppSheetRoute<T> extends ModalRoute<T> {
  AppSheetRoute({
    required this.presentation,
    required this.builder,
    this.presentationResolver,
  }) {
    effectivePresentation = ValueNotifier<AppSheetPresentation>(presentation);
    effectivePresentation.addListener(_reportBarrierChange);
  }

  static const _transitionMillis = 220;

  static const _transitionDuration = Duration(milliseconds: _transitionMillis);

  static const _barrierColor = Color(0x52101212);

  static const _openBarrierColor = Color(0x00000000);

  static const _slideBeginDy = 0.06;

  static const _slideBegin = Offset(0, _slideBeginDy);

  final WidgetBuilder builder;

  final AppSheetPresentation presentation;

  final AppSheetPresentation Function(BuildContext)? presentationResolver;

  late final ValueNotifier<AppSheetPresentation> effectivePresentation;

  bool _disposed = false;

  AppSheetPresentation resolveLive(BuildContext context) =>
      presentationResolver?.call(context) ?? presentation;

  void updateEffective(AppSheetPresentation value) {
    if (effectivePresentation.value == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (effectivePresentation.value == value) return;
      effectivePresentation.value = value;
    });
  }

  void _reportBarrierChange() => changedInternalState();

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
  Color? get barrierColor =>
      effectivePresentation.value == AppSheetPresentation.open
      ? _openBarrierColor
      : _barrierColor;

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
    return _AppSheetPage<T>(route: this);
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
    _disposed = true;
    effectivePresentation.dispose();
    _alerts.dispose();
    _alertAction.dispose();
    super.dispose();
  }
}

// MARK: - Page

class _AppSheetPage<T> extends StatefulWidget {
  const _AppSheetPage({required this.route});

  final AppSheetRoute<T> route;

  @override
  State<_AppSheetPage<T>> createState() => _AppSheetPageState<T>();
}

class _AppSheetPageState<T> extends State<_AppSheetPage<T>> {
  static const _desktopAlertTop = 16.0;

  static const _compactAlertTop = 12.0;

  static const _bottomAlignment = Alignment.bottomCenter;

  static const _centerAlignment = Alignment.center;

  static const _openAlignment = Alignment.topRight;

  static const _openWidthDivisor = 2.0;

  static const _noTopPadding = 0.0;

  @override
  Widget build(BuildContext context) {
    final presentation = widget.route.resolveLive(context);
    widget.route.updateEffective(presentation);
    final media = MediaQuery.of(context);
    final open = presentation == AppSheetPresentation.open;
    final desktop = presentation == AppSheetPresentation.desktop;
    final alignment = open
        ? _openAlignment
        : desktop
        ? _centerAlignment
        : _bottomAlignment;
    final sheet = Padding(
      padding: EdgeInsets.only(
        top: open ? media.padding.top : _noTopPadding,
        bottom: media.viewInsets.bottom,
      ),
      child: Builder(builder: widget.route.builder),
    );
    final positionedSheet = Align(
      alignment: alignment,
      child: SizedBox(
        width: open ? media.size.width / _openWidthDivisor : null,
        height: open ? media.size.height - media.padding.bottom : null,
        child: sheet,
      ),
    );
    final alertTop =
        media.padding.top + (desktop ? _desktopAlertTop : _compactAlertTop);
    final overlay = _SheetAlertOverlay(
      alerts: widget.route._alerts,
      alertAction: widget.route._alertAction,
      alertTop: alertTop,
    );

    return AppSheetAlertSlot(
      presentation: presentation,
      alerts: widget.route._alerts,
      alertAction: widget.route._alertAction,
      child: Stack(children: [positionedSheet, overlay]),
    );
  }
}

// MARK: - Alert Overlay

class _SheetAlertOverlay extends StatelessWidget {
  const _SheetAlertOverlay({
    required this.alerts,
    required this.alertAction,
    required this.alertTop,
  });

  static const _overlayHorizontalInset = 12.0;

  static const _sheetMaxWidth = 440.0;

  final ValueNotifier<SheetAlertData?> alerts;

  final ValueNotifier<VoidCallback?> alertAction;

  final double alertTop;

  @override
  Widget build(BuildContext context) {
    final banner = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
      child: _SheetAlertListener(alerts: alerts, alertAction: alertAction),
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
  const _SheetAlertListener({required this.alerts, required this.alertAction});

  final ValueNotifier<SheetAlertData?> alerts;

  final ValueNotifier<VoidCallback?> alertAction;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SheetAlertData?>(
      valueListenable: alerts,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();
        return _SheetAlertActionListener(alertAction: alertAction, data: data);
      },
    );
  }
}

class _SheetAlertActionListener extends StatelessWidget {
  const _SheetAlertActionListener({
    required this.alertAction,
    required this.data,
  });

  final ValueNotifier<VoidCallback?> alertAction;

  final SheetAlertData data;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VoidCallback?>(
      valueListenable: alertAction,
      builder: (context, action, _) => SheetAlert(data: data, onAction: action),
    );
  }
}
