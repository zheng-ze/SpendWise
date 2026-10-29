import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
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

class AppSheetRoute<T> extends ModalRoute<T> {
  AppSheetRoute({
    required this.presentation,
    required this.builder,
    this.showShellNavigation = false,
    this.presentationResolver,
  }) : _livePresentation = presentation;

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

  AppSheetPresentation _livePresentation;

  bool _barrierUpdateScheduled = false;

  bool get dimsBackground => _livePresentation == AppSheetPresentation.phone;

  bool _disposed = false;
  ShellPresentationController? _presentationController;
  Route<dynamic>? _predecessor;

  Route<dynamic>? get nearestNonSheetPredecessor {
    final predecessor = _predecessor;
    if (predecessor is AppSheetRoute<dynamic>) {
      return predecessor.nearestNonSheetPredecessor;
    }
    return predecessor;
  }

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    super.didChangePrevious(previousRoute);
    if (identical(_predecessor, previousRoute)) return;
    _predecessor = previousRoute;
    _presentationController?.routesChanged();
  }

  @override
  void install() {
    super.install();
    final context = navigator?.context;
    if (context == null) return;
    _presentationController = ShellPresentationScope.read(context);
    _presentationController?.register(this);
    completed.then((_) => _presentationController?.release(this));
  }

  AppSheetPresentation resolveLive(BuildContext context) =>
      presentationResolver?.call(context) ?? presentation;

  AppSheetPresentation syncPresentation(BuildContext context) {
    final live = resolveLive(context);
    if (live == _livePresentation) return live;
    _livePresentation = live;
    _scheduleBarrierUpdate();
    return live;
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

  @override
  Widget build(BuildContext context) {
    final presentation = widget.route.syncPresentation(context);
    final media = MediaQuery.of(context);
    final phone = presentation == AppSheetPresentation.phone;
    final desktop = presentation == AppSheetPresentation.desktop;
    final open = presentation == AppSheetPresentation.open;
    final sheet = Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Builder(builder: widget.route.builder),
    );
    final bounds = phone ? null : _dockedBounds(media, desktop);
    final placement = bounds ?? Offset.zero & media.size;
    final alignment = bounds == null
        ? Alignment.bottomCenter
        : Alignment.topRight;
    final sized = SizedBox(
      width: bounds?.width,
      height: bounds?.height,
      child: sheet,
    );
    final positionedSheet = Positioned.fromRect(
      rect: placement,
      child: Align(alignment: alignment, child: sized),
    );
    final alertTop =
        media.padding.top + (desktop ? _desktopAlertTop : _compactAlertTop);
    final overlay = _SheetAlertOverlay(
      alerts: widget.route._alerts,
      alertAction: widget.route._alertAction,
      alertTop: alertTop,
      bounds: bounds,
    );
    final showsRail = widget.route.showShellNavigation && open;
    final navigation = showsRail ? const _OpenRailOverlay() : null;
    return AppSheetAlertSlot(
      presentation: presentation,
      alerts: widget.route._alerts,
      alertAction: widget.route._alertAction,
      child: Stack(children: [positionedSheet, overlay, ?navigation]),
    );
  }

  Rect _dockedBounds(MediaQueryData media, bool desktop) {
    final mode = desktop ? ShellLayoutMode.desktop : ShellLayoutMode.open;
    return resolveShellPaneGeometry(
      mode: mode,
      windowSize: media.size,
      padding: media.padding,
    ).sheetBounds;
  }
}

class _OpenRailOverlay extends ConsumerWidget {
  const _OpenRailOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDestinationProvider);
    final rail = OpenRail(
      selected: selected,
      onDestinationSelected: (destination) =>
          _selectAndDismiss(context, ref, destination),
      onAdd: () {},
    );
    final safeRail = SafeArea(left: false, right: false, child: rail);
    final positioned = Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: _railRightPadding + _railBottomPadding,
        child: safeRail,
      ),
    );
    return Material(type: MaterialType.transparency, child: positioned);
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
    required this.bounds,
  });

  static const _overlayHorizontalInset = 12.0;

  static const _sheetMaxWidth = 440.0;

  final ValueNotifier<SheetAlertData?> alerts;

  final ValueNotifier<VoidCallback?> alertAction;

  final double alertTop;

  final Rect? bounds;

  @override
  Widget build(BuildContext context) {
    final banner = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
      child: _SheetAlertListener(alerts: alerts, alertAction: alertAction),
    );

    final centered = Center(child: banner);
    final bounds = this.bounds;
    if (bounds == null) {
      return Positioned(
        top: alertTop,
        left: _overlayHorizontalInset,
        right: _overlayHorizontalInset,
        child: centered,
      );
    }
    return Positioned(
      top: alertTop,
      left: bounds.left + _overlayHorizontalInset,
      width: bounds.width - 2 * _overlayHorizontalInset,
      child: centered,
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
