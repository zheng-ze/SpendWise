import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const shellDetailPaneKey = ValueKey('shell-detail-pane');
const shellDetailDividerKey = ValueKey('shell-detail-divider');
const shellDetailCloseKey = ValueKey('shell-detail-close');

const _detailHeaderPadding = EdgeInsets.fromLTRB(16, 14, 16, 12);
const _detailBodyPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);
const _detailHeaderGap = 8.0;
const _detailHeaderActionRunGap = 6.0;
const _detailSubtitleGap = 2.0;
const _detailCloseIconSize = 18.0;
const _detailDividerWidth = 1.0;
const _floatingActionRightInset = 3.0;
const _floatingActionBottomInset = 10.0;
const _minimumPinnedDetailPaneHeight = 280.0;
const _overflowDetailBodyHeight = 160.0;
const _minimumDetailPaneWidth = 0.0;
const _detailPaneTopInset = 0.0;
const _detailPaneBottomInset = 0.0;

enum ShellPagePresentation { fullPage, singleColumn }

class ShellPaneScope extends InheritedWidget {
  const ShellPaneScope({
    super.key,
    required this.mode,
    required this.safeBodyWidth,
    required this.addPresented,
    required super.child,
  });

  final ShellLayoutMode mode;
  final double safeBodyWidth;
  final bool addPresented;

  static ShellPaneScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellPaneScope>();
    assert(scope != null);
    return scope!;
  }

  @override
  bool updateShouldNotify(ShellPaneScope oldWidget) =>
      mode != oldWidget.mode ||
      safeBodyWidth != oldWidget.safeBodyWidth ||
      addPresented != oldWidget.addPresented;
}

class ShellDetail {
  const ShellDetail({
    required this.id,
    required this.title,
    required this.bodyBuilder,
    required this.onClose,
    this.subtitle,
    this.headerActions = const [],
  });

  final String id;
  final String title;
  final String? subtitle;
  final WidgetBuilder bodyBuilder;
  final VoidCallback onClose;
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
        final open = scope.mode == ShellLayoutMode.open;
        final hasDetailPane = open && detail != null && !scope.addPresented;
        final pageWidth = !open
            ? constraints.maxWidth
            : scope.addPresented || detail != null
            ? math.min(scope.safeBodyWidth / 2, constraints.maxWidth)
            : constraints.maxWidth;
        final detailWidth = math.max(
          _minimumDetailPaneWidth,
          scope.safeBodyWidth / 2 - openRailGutter,
        );
        final presentation = pageWidth < constraints.maxWidth
            ? ShellPagePresentation.singleColumn
            : ShellPagePresentation.fullPage;
        final page = SizedBox(
          width: pageWidth,
          height: constraints.maxHeight,
          child: pageBuilder(context, presentation),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Align(alignment: Alignment.topLeft, child: page),
            if (detail != null)
              Positioned(
                left: scope.safeBodyWidth / 2,
                top: _detailPaneTopInset,
                bottom: _detailPaneBottomInset,
                width: detailWidth,
                child: Offstage(
                  offstage: !hasDetailPane,
                  child: _DetailPane(
                    key: ValueKey(detail!.id),
                    detail: detail!,
                  ),
                ),
              ),
            if (hasDetailPane)
              Positioned(
                key: shellDetailDividerKey,
                left: scope.safeBodyWidth / 2,
                top: _detailPaneTopInset,
                bottom: _detailPaneBottomInset,
                width: _detailDividerWidth,
                child: ColoredBox(color: context.colors.edge),
              ),
            if (showFloatingAction)
              Positioned(
                right: _floatingActionRightInset,
                bottom: _floatingActionBottomInset,
                child: floatingAction!,
              ),
          ],
        );
      },
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({super.key, required this.detail});

  final ShellDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
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
    final header = Padding(
      padding: _detailHeaderPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: _detailHeaderGap),
              TextButton.icon(
                key: shellDetailCloseKey,
                onPressed: detail.onClose,
                icon: Icon(Icons.close, size: _detailCloseIconSize),
                label: const Text('Close'),
              ),
            ],
          ),
          if (detail.headerActions.isNotEmpty)
            Wrap(
              spacing: _detailHeaderGap,
              runSpacing: _detailHeaderActionRunGap,
              children: detail.headerActions,
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollWholePane =
            constraints.maxHeight < _minimumPinnedDetailPaneHeight * textScale;
        final body = Padding(
          padding: _detailBodyPadding,
          child: detail.bodyBuilder(context),
        );
        return KeyedSubtree(
          key: shellDetailPaneKey,
          child: scrollWholePane
              ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      SizedBox(height: _overflowDetailBodyHeight, child: body),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(child: body),
                  ],
                ),
        );
      },
    );
  }
}
