import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/sheets/tray.dart';

const loadErrorDefaultTitle = "Couldn't load this page";
const loadErrorRetryLabel = 'Try again';
const _viewPadding = EdgeInsets.all(12);
const _contentGap = 8.0;

class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = loadErrorDefaultTitle,
  });

  final Object error;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Text('$error'),
        const SizedBox(height: _contentGap),
        PrimaryButton(label: loadErrorRetryLabel, onPressed: onRetry),
      ],
    );
    return Padding(
      padding: _viewPadding,
      child: Tray(child: content),
    );
  }
}
