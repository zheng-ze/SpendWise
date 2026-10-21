import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _errorTitle = "Couldn't load your spending";
const _errorBody = 'Please try again.';
const _retryLabel = 'Retry';
const _emptyTitle = 'See where your money goes';
const _emptyBody =
    'Record an expense to start your monthly picture and breakdown.';

// MARK: - Loading
class TrendsLoadingView extends StatelessWidget {
  const TrendsLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const LoadingTrays();
}

// MARK: - Error
class TrendsErrorView extends StatelessWidget {
  const TrendsErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  static const _radius = 10.0;
  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 10.0;
  static const _verticalMargin = 8.0;
  static const _titleFontSize = 12.0;
  static const _bodyFontSize = 10.0;
  static const _bodyOpacity = 0.9;
  static const _bodyGap = 2.0;
  static const _retryTopMargin = 2.0;
  static const _semiBold = FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = Text(
      _errorTitle,
      style: TextStyle(
        fontSize: _titleFontSize,
        fontWeight: _semiBold,
        color: colors.error,
      ),
    );
    final body = Opacity(
      opacity: _bodyOpacity,
      child: Text(
        _errorBody,
        style: TextStyle(fontSize: _bodyFontSize, color: colors.error),
      ),
    );
    final message = Container(
      margin: const EdgeInsets.symmetric(vertical: _verticalMargin),
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.errorBg,
        border: Border.all(color: colors.error),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: _bodyGap),
          body,
        ],
      ),
    );
    final retry = Padding(
      padding: const EdgeInsets.only(top: _retryTopMargin),
      child: PrimaryButton(label: _retryLabel, onPressed: onRetry),
    );
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [message, retry],
      ),
    );
  }
}

// MARK: - Empty
class TrendsEmptyView extends StatelessWidget {
  const TrendsEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.bar_chart,
      title: _emptyTitle,
      body: _emptyBody,
    );
  }
}
