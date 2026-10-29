import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const shellDetailPaneKey = ValueKey('shell-detail-pane');
const shellDetailDividerKey = ValueKey('shell-detail-divider');
const shellDetailCloseKey = ValueKey('shell-detail-close');

const _detailHeaderPadding = EdgeInsets.fromLTRB(16, 14, 16, 12);
const _detailBodyPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);
const _detailHeaderGap = 8.0;
const _detailSubtitleGap = 2.0;
const _detailCloseIconSize = 18.0;
const _detailDividerWidth = 1.0;
const _floatingActionRightInset = 3.0;
const _floatingActionBottomInset = 10.0;
const _minimumPinnedDetailPaneHeight = 280.0;
const _minimumDetailPaneWidth = 0.0;
const _pageSlotKey = ValueKey('shell-page-slot');
const _detailSlotKey = ValueKey('shell-detail-slot');
const _floatingActionSlotKey = ValueKey('shell-floating-action-slot');

enum ShellPagePresentation { fullPage, singleColumn }

class ShellPaneScope extends InheritedWidget {
  const ShellPaneScope({
    super.key,
    required this.mode,
    required this.splitOffset,
    required this.addPresented,
    this.sheetCovered = false,
    required super.child,
  });

  final ShellLayoutMode mode;
  final double splitOffset;
  final bool addPresented;
  final bool sheetCovered;

  static ShellPaneScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellPaneScope>();
    assert(scope != null);
    return scope!;
  }

  static ShellPaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellPaneScope>();

  @override
  bool updateShouldNotify(ShellPaneScope oldWidget) =>
      mode != oldWidget.mode ||
      splitOffset != oldWidget.splitOffset ||
      addPresented != oldWidget.addPresented ||
      sheetCovered != oldWidget.sheetCovered;
}

class ShellDetail {
  const ShellDetail({
    required this.id,
    required this.title,
    required this.bodyBuilder,
    this.onClose,
    this.subtitle,
    this.headerActions = const [],
  });

  final String id;
  final String title;
  final String? subtitle;
  final WidgetBuilder bodyBuilder;
  final VoidCallback? onClose;
  final List<Widget> headerActions;
}

class ShellPaneHost extends StatelessWidget {
  const ShellPaneHost({
    super.key,
    required this.pageBuilder,
    this.detail,
    this.floatingAction,
  });

  final Widget Function(
    BuildContext context,
    ShellPagePresentation presentation,
  )
  pageBuilder;
  final ShellDetail? detail;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    final scope = ShellPaneScope.of(context);
    final pageActive = DestinationActivity.of(context);
    final routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final showFloatingAction =
        floatingAction != null &&
        scope.mode == ShellLayoutMode.open &&
        !scope.addPresented &&
        pageActive &&
        routeCurrent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = scope.mode != ShellLayoutMode.phone;
        final hasDetailPane = wide && detail != null;
        final shifted = hasDetailPane && scope.sheetCovered;
        final splitPage = hasDetailPane || (wide && scope.sheetCovered);
        final splitOffset = scope.splitOffset.clamp(0.0, constraints.maxWidth);
        final pageWidth = splitPage ? splitOffset : constraints.maxWidth;
        final detailWidth = math.max(
          _minimumDetailPaneWidth,
          constraints.maxWidth - splitOffset,
        );
        final presentation = pageWidth < constraints.maxWidth
            ? ShellPagePresentation.singleColumn
            : ShellPagePresentation.fullPage;

        final pageContent = pageBuilder(context, presentation);
        final pageForPresentation = MediaQuery.removePadding(
          context: context,
          removeRight: presentation == ShellPagePresentation.singleColumn,
          child: pageContent,
        );
        final page = Align(
          key: _pageSlotKey,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: pageWidth,
            height: constraints.maxHeight,
            child: _InactivePaneIsolation(
              active: !shifted,
              child: pageForPresentation,
            ),
          ),
        );
        final currentDetail = detail;
        final detailSlot = currentDetail == null
            ? null
            : Align(
                key: _detailSlotKey,
                alignment: shifted ? Alignment.topLeft : Alignment.topRight,
                child: SizedBox(
                  width: shifted ? splitOffset : detailWidth,
                  height: constraints.maxHeight,
                  child: _InactivePaneIsolation(
                    active: hasDetailPane,
                    child: _DetailPane(
                      key: ValueKey(currentDetail.id),
                      detail: currentDetail,
                    ),
                  ),
                ),
              );
        final dividerLine = SizedBox(
          width: _detailDividerWidth,
          height: constraints.maxHeight,
          child: ColoredBox(color: context.colors.edge),
        );
        final divider = !hasDetailPane || shifted
            ? null
            : Align(
                key: shellDetailDividerKey,
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: splitOffset),
                  child: dividerLine,
                ),
              );
        final action = !showFloatingAction
            ? null
            : Positioned(
                key: _floatingActionSlotKey,
                right: _floatingActionRightInset,
                bottom: _floatingActionBottomInset,
                child: floatingAction!,
              );

        return Stack(
          fit: StackFit.expand,
          children: [page, ?detailSlot, ?divider, ?action],
        );
      },
    );
  }
}

class _InactivePaneIsolation extends StatelessWidget {
  const _InactivePaneIsolation({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final focus = ExcludeFocus(excluding: !active, child: child);
    final ticker = TickerMode(enabled: active, child: focus);
    return Offstage(offstage: !active, child: ticker);
  }
}

class _DetailPane extends StatefulWidget {
  const _DetailPane({super.key, required this.detail});

  final ShellDetail detail;

  @override
  State<_DetailPane> createState() => _DetailPaneState();
}

class _DetailPaneState extends State<_DetailPane> {
  final _bodyKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final header = _DetailHeader(detail: detail);
    final body = KeyedSubtree(
      key: _bodyKey,
      child: Padding(
        padding: _detailBodyPadding,
        child: detail.bodyBuilder(context),
      ),
    );

    return SafeArea(
      left: false,
      right: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollWholePane =
              constraints.maxHeight <
              _minimumPinnedDetailPaneHeight * textScale;
          return KeyedSubtree(
            key: shellDetailPaneKey,
            child: _DetailLayout(
              header: header,
              body: body,
              scrollWholePane: scrollWholePane,
              paneHeight: constraints.maxHeight,
            ),
          );
        },
      ),
    );
  }
}

class _DetailLayout extends StatelessWidget {
  const _DetailLayout({
    required this.header,
    required this.body,
    required this.scrollWholePane,
    required this.paneHeight,
  });

  final Widget header;
  final Widget body;
  final bool scrollWholePane;
  final double paneHeight;

  @override
  Widget build(BuildContext context) {
    final bodySlot = scrollWholePane
        ? SizedBox(height: paneHeight, child: body)
        : Expanded(child: body);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, bodySlot],
    );
    return scrollWholePane ? SingleChildScrollView(child: column) : column;
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.detail});

  final ShellDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detail.title, style: Theme.of(context).textTheme.titleLarge),
        if (detail.subtitle case final subtitle?) ...[
          const SizedBox(height: _detailSubtitleGap),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.subtext),
          ),
        ],
      ],
    );
    final closeButton = detail.onClose == null
        ? null
        : TextButton.icon(
            key: shellDetailCloseKey,
            onPressed: detail.onClose,
            icon: Icon(Icons.close, size: _detailCloseIconSize),
            label: const Text('Close'),
          );
    final actions = [
      for (final action in detail.headerActions) ...[
        const SizedBox(width: _detailHeaderGap),
        action,
      ],
      if (closeButton != null) ...[
        const SizedBox(width: _detailHeaderGap),
        closeButton,
      ],
    ];
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        ...actions,
      ],
    );
    return Padding(padding: _detailHeaderPadding, child: row);
  }
}
