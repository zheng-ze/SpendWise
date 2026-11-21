import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_slot_grid.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Screen

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({
    super.key,
    this.layoutMode = ShellLayoutMode.phone,
    this.presentation = ShellPagePresentation.fullPage,
  });

  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(overviewViewModelProvider);
    final viewModel = ref.watch(overviewViewModelProvider.notifier);
    return AsyncValueView(
      value: asyncState,
      onRetry: () => ref.invalidate(overviewViewModelProvider),
      fullPage: true,
      data: (viewState) => _OverviewBody(
        layoutMode: layoutMode,
        presentation: presentation,
        viewState: viewState,
        viewModel: viewModel,
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.layoutMode,
    required this.presentation,
    required this.viewState,
    required this.viewModel,
  });

  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;
  final OverviewViewState viewState;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: overviewPagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverviewHeader(day: viewState.day),
              OverviewSlotGrid(
                layoutMode: layoutMode,
                presentation: presentation,
                viewState: viewState,
                viewModel: viewModel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: - Header

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.day});

  final DateTime day;

  static const _bottomPadding = 14.0;
  static const _dateGap = 2.0;
  static const _titleFontSize = 26.0;
  static const _titleLineHeight = 1.12;
  static const _titleLetterSpacing = -0.7;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: _bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatWeekdayDate(day),
            style: context.text.caption.copyWith(color: colors.subtext),
          ),
          const SizedBox(height: _dateGap),
          Text(
            overviewTitle,
            style: TextStyle(
              fontSize: _titleFontSize,
              fontWeight: SpendWiseText.semibold,
              height: _titleLineHeight,
              letterSpacing: _titleLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}
