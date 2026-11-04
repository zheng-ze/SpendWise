import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/load_error_view.dart';

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
    this.errorTitle = loadErrorDefaultTitle,
    this.fullPage = false,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;
  final String errorTitle;
  final bool fullPage;

  @override
  Widget build(BuildContext context) {
    if (value case AsyncError(:final error)) {
      final view = LoadErrorView(
        error: error,
        onRetry: onRetry,
        title: errorTitle,
      );
      if (!fullPage) return view;
      return Scaffold(
        body: SafeArea(
          child: Center(child: SingleChildScrollView(child: view)),
        ),
      );
    }
    if (!value.hasValue) return const SizedBox.shrink();
    return data(value.requireValue);
  }
}
