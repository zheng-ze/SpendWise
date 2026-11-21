import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const loadErrorDefaultTitle = "Couldn't load this page";
const loadErrorRetryLabel = 'Try again';
const loadErrorTrayPadding = EdgeInsets.all(12);
const _contentGap = 8.0;

// MARK: - LoadErrorView
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = loadErrorDefaultTitle,
    this.padding = loadErrorTrayPadding,
  }) : compact = false;

  const LoadErrorView.box({
    super.key,
    required Object message,
    this.title,
    this.onRetry,
  }) : error = message,
       padding = EdgeInsets.zero,
       compact = true;

  final Object error;
  final VoidCallback? onRetry;
  final String? title;
  final EdgeInsets padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return _LoadErrorBox(view: this);

    final onRetry = this.onRetry;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title'),
        Text('$error'),
        const SizedBox(height: _contentGap),
        if (onRetry != null)
          PrimaryButton(label: loadErrorRetryLabel, onPressed: onRetry),
      ],
    );
    return Padding(
      padding: padding,
      child: Tray(child: content),
    );
  }
}

// MARK: - LoadErrorBox
class _LoadErrorBox extends StatelessWidget {
  const _LoadErrorBox({required this.view});

  final LoadErrorView view;

  static const _cornerRadius = 10.0;
  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 10.0;
  static const _verticalMargin = 8.0;
  static const _messageLineHeight = 1.45;
  static const _titleGap = 2.0;
  static const _retryTopGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = view.title;
    final onRetry = view.onRetry;
    final titleText = title == null
        ? null
        : Text(
            title,
            style: context.text.body.copyWith(
              fontWeight: SpendWiseText.semibold,
              color: colors.error,
            ),
          );
    final message = Text(
      '${view.error}',
      style: context.text.body.copyWith(
        height: _messageLineHeight,
        color: colors.error,
      ),
    );
    final content = <Widget>[
      if (titleText != null) ...[titleText, const SizedBox(height: _titleGap)],
      message,
      if (onRetry != null) ...[
        const SizedBox(height: _retryTopGap),
        PrimaryButton(label: loadErrorRetryLabel, onPressed: onRetry),
      ],
    ];
    final decoration = BoxDecoration(
      color: colors.errorBg,
      border: Border.all(color: colors.error),
      borderRadius: BorderRadius.circular(_cornerRadius),
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        decoration: decoration,
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        margin: const EdgeInsets.symmetric(vertical: _verticalMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      ),
    );
  }
}
