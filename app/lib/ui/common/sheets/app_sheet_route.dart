import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/phone_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_presentation_controller.dart';
import 'package:spendwise/ui/shell/shell_pane_geometry.dart';

// MARK: - Constants

const _paintOrigin = Offset.zero;
const _railRightPadding = EdgeInsets.only(right: openRailRightInset);
const _railBottomPadding = EdgeInsets.only(bottom: openRailBottomInset);

// MARK: - Show

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required AppSheetPresentation presentation,
  AppSheetPresentation Function(BuildContext)? presentationResolver,
  bool showShellNavigation = false,
  void Function(AppSheetRoute<T>)? onRouteCreated,
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = AppSheetRoute<T>(
    presentation: presentation,
    presentationResolver: presentationResolver,
    builder: builder,
    showShellNavigation: showShellNavigation,
  );
  onRouteCreated?.call(route);
  return navigator.push<T>(route);
}

// MARK: - Route

class AppSheetRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is AppSheetRoute<dynamic>) {
      route.initializePredecessor(previousRoute);
    }
  }
}

typedef AppSheetResolvedPresentation = ({
  AppSheetPresentation presentation,
  bool isDocked,
  Rect? bounds,
});

class AppSheetRoute<T> extends ModalRoute<T> {
  AppSheetRoute({
    required this.presentation,
    required this.builder,
    this.showShellNavigation = false,
    this.presentationResolver,
  }) {
    _resolvedPresentation = (
      presentation: presentation,
      isDocked: presentation == AppSheetPresentation.open,
      bounds: null,
    );
  }

  static const _transitionMillis = 220;

  static const _transitionDuration = Duration(milliseconds: _transitionMillis);

  static const _barrierColor = Color(0x52101212);

  static const _openBarrierColor = Color(0x00000000);

  static const _slideBeginDy = 0.06;

  static const _slideBegin = Offset(0, _slideBeginDy);

  final WidgetBuilder builder;

  final bool showShellNavigation;

  final AppSheetPresentation presentation;

  final AppSheetPresentation Function(BuildContext)? presentationResolver;

  late AppSheetResolvedPresentation _resolvedPresentation;

  AppSheetResolvedPresentation get resolvedPresentation =>
      _resolvedPresentation;
  bool _barrierUpdateScheduled = false;

  bool get isDocked => resolvedPresentation.isDocked;
  bool get dimsBackground => !isDocked;

  bool _disposed = false;
  ShellPresentationController? _presentationController;
  Route<dynamic>? _predecessor;
  bool _predecessorInitialized = false;

  bool get predecessorInitialized => _predecessorInitialized;

  Route<dynamic>? get nearestNonSheetPredecessor {
    assert(_presentationController == null || _predecessorInitialized);
    final predecessor = _predecessor;
    if (predecessor is AppSheetRoute<dynamic>) {
      return predecessor.nearestNonSheetPredecessor;
    }
    return predecessor;
  }

  void initializePredecessor(Route<dynamic>? previousRoute) {
    if (_predecessorInitialized && identical(_predecessor, previousRoute)) {
      return;
    }
    _predecessorInitialized = true;
    _predecessor = previousRoute;
    _refreshPlacement();
    _presentationController?.routesChanged();
  }

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    super.didChangePrevious(previousRoute);
    initializePredecessor(previousRoute);
  }

  @override
  void install() {
    super.install();
    final context = navigator?.context;
    if (context == null) return;
    _presentationController = ShellPresentationScope.read(context);
    _presentationController?.register(this);
    _presentationController?.addListener(_refreshPlacement);
    completed.then((_) => _presentationController?.release(this));
  }

  AppSheetPresentation resolveLive(BuildContext context) =>
      presentationResolver?.call(context) ?? presentation;

  AppSheetResolvedPresentation resolvePresentation(BuildContext context) {
    final presentation = resolveLive(context);
    final controller = ShellPresentationScope.maybeOf(context);
    final mode = presentation == AppSheetPresentation.desktop
        ? ShellLayoutMode.desktop
        : ShellLayoutMode.open;
    final geometry = resolveShellPaneGeometry(
      mode: mode,
      windowSize: MediaQuery.sizeOf(context),
      padding: MediaQuery.paddingOf(context),
    );
    final resolved = _resolvePlacement(presentation, geometry, controller);
    _setResolved(resolved);
    return resolved;
  }

  AppSheetResolvedPresentation _resolvePlacement(
    AppSheetPresentation presentation,
    ShellPaneGeometry geometry,
    ShellPresentationController? controller,
  ) {
    final shellRoute = controller?.shellRoute;
    final coversShell =
        shellRoute != null && identical(nearestNonSheetPredecessor, shellRoute);
    final desktopDocked =
        presentation == AppSheetPresentation.desktop &&
        coversShell &&
        (controller?.exposesDetail ?? false);
    final docked = presentation == AppSheetPresentation.open || desktopDocked;
    return (
      presentation: presentation,
      isDocked: docked,
      bounds: docked ? geometry.sheetBounds : null,
    );
  }

  void _refreshPlacement() {
    if (_disposed || !_predecessorInitialized) return;
    final controller = _presentationController;
    final geometry = controller?.geometry;
    if (geometry == null) return;
    final presentation = resolvedPresentation.presentation;
    final resolved = _resolvePlacement(presentation, geometry, controller);
    _setResolved(resolved);
  }

  void _setResolved(AppSheetResolvedPresentation resolved) {
    if (resolvedPresentation == resolved) return;
    _resolvedPresentation = resolved;
    _scheduleBarrierUpdate();
  }

  void _scheduleBarrierUpdate() {
    if (_barrierUpdateScheduled) return;
    _barrierUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barrierUpdateScheduled = false;
      if (!_disposed) changedInternalState();
    });
  }

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
  Color? get barrierColor => dimsBackground ? _barrierColor : _openBarrierColor;

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
    final transition = FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
    return transition;
  }

  @override
  void dispose() {
    _disposed = true;
    _presentationController?.removeListener(_refreshPlacement);
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

  static const _noInset = 0.0;

  @override
  Widget build(BuildContext context) {
    final resolved = widget.route.resolvePresentation(context);
    final presentation = resolved.presentation;
    final docked = resolved.isDocked;
    final media = MediaQuery.of(context);
    final desktop = presentation == AppSheetPresentation.desktop;
    final alignment = docked
        ? _openAlignment
        : desktop
        ? _centerAlignment
        : _bottomAlignment;
    final sheet = Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Builder(builder: widget.route.builder),
    );
    final bounds = resolved.bounds;
    final placementPadding = bounds == null
        ? EdgeInsets.only(
            bottom: widget.route.showShellNavigation && !desktop
                ? phoneBarNavigationHeight(context)
                : _noInset,
          )
        : EdgeInsets.fromLTRB(
            bounds.left,
            bounds.top,
            media.size.width - bounds.right,
            media.size.height - bounds.bottom,
          );
    final positionedSheet = Padding(
      padding: placementPadding,
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: bounds?.width,
          height: bounds?.height,
          child: sheet,
        ),
      ),
    );
    final alertTop =
        media.padding.top + (desktop ? _desktopAlertTop : _compactAlertTop);
    final overlay = _SheetAlertOverlay(
      alerts: widget.route._alerts,
      alertAction: widget.route._alertAction,
      alertTop: alertTop,
    );

    final navigation = widget.route.showShellNavigation && !desktop
        ? const _ShellNavigationOverlay()
        : null;
    return AppSheetAlertSlot(
      presentation: presentation,
      isDocked: docked,
      alerts: widget.route._alerts,
      alertAction: widget.route._alertAction,
      child: Stack(children: [positionedSheet, overlay, ?navigation]),
    );
  }
}

class _ShellNavigationOverlay extends ConsumerWidget {
  const _ShellNavigationOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(shellLayoutModeProvider);
    final selected = ref.watch(selectedDestinationProvider);
    final navigation = switch (mode) {
      ShellLayoutMode.phone => Align(
        alignment: Alignment.bottomCenter,
        child: PhoneBar(
          selected: selected,
          onDestinationSelected: (destination) =>
              _selectAndDismiss(context, ref, destination),
          onAdd: () {},
        ),
      ),
      ShellLayoutMode.open => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: _railRightPadding + _railBottomPadding,
          child: SafeArea(
            left: false,
            right: false,
            child: OpenRail(
              selected: selected,
              onDestinationSelected: (destination) =>
                  _selectAndDismiss(context, ref, destination),
              onAdd: () {},
            ),
          ),
        ),
      ),
      ShellLayoutMode.desktop => const SizedBox.shrink(),
    };
    return Material(type: MaterialType.transparency, child: navigation);
  }

  void _selectAndDismiss(
    BuildContext context,
    WidgetRef ref,
    ShellDestination destination,
  ) {
    ref.read(selectedDestinationProvider.notifier).state = destination;
    Navigator.of(context, rootNavigator: true).maybePop();
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
