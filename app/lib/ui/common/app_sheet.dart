import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheet_alert.dart';
import 'package:spendwise/ui/shell/layout_breakpoints.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push<T>(AppSheetRoute<T>(builder: builder));
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
        0.66 *
        (media.size.height - media.padding.top - media.viewInsets.bottom);
    final colors = context.colors;
    final footer = widget.footer;
    final inputSurface = widget.inputSurface;
    final content = <Widget>[
      const _SheetHandle(),
      widget.header,
      Flexible(child: SingleChildScrollView(child: widget.body)),
    ];
    if (footer != null) content.add(footer);
    if (inputSurface != null) content.add(inputSurface);
    final sheetBody = Column(mainAxisSize: MainAxisSize.min, children: content);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: cap,
        maxWidth: desktop ? 440 : double.infinity,
      ),
      child: Material(
        color: colors.raised,
        borderRadius: desktop
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(22)),
        child: Container(
          decoration: BoxDecoration(
            border: desktop
                ? Border.all(color: colors.control)
                : Border(top: BorderSide(color: colors.control, width: 2)),
            borderRadius: desktop
                ? BorderRadius.circular(16)
                : const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: sheetBody,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 4,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.control,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class AppSheetRoute<T> extends ModalRoute<T> {
  AppSheetRoute({required this.builder});

  final WidgetBuilder builder;

  late final ValueNotifier<SheetAlertData?> _alerts =
      ValueNotifier<SheetAlertData?>(null);

  late final ValueNotifier<VoidCallback?> _alertAction =
      ValueNotifier<VoidCallback?>(null);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => const Color(0x52101212);

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
      begin: const Offset(0, 0.06),
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
    final alertTop = media.padding.top + (desktop ? 16 : 12);

    return Stack(
      children: [
        positionedSheet,
        Positioned(
          top: alertTop,
          left: 12,
          right: 12,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ValueListenableBuilder<SheetAlertData?>(
                valueListenable: slot.alerts,
                builder: (context, data, _) {
                  if (data == null) return const SizedBox.shrink();
                  return ValueListenableBuilder<VoidCallback?>(
                    valueListenable: slot.alertAction,
                    builder: (context, action, _) =>
                        SheetAlert(data: data, onAction: action),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
