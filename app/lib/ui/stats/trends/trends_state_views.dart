import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/empty_state.dart';
import 'package:spendwise/ui/common/feedback/load_error_view.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';

// MARK: - Constants
const _errorTitle = "Couldn't load your spending";
const _errorBody = 'Please try again.';
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

  @override
  Widget build(BuildContext context) {
    return LoadErrorView.box(
      title: _errorTitle,
      message: _errorBody,
      onRetry: onRetry,
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
