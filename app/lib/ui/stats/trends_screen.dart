import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/navigation/labelled_back_button.dart';

const _trendsTitle = 'Trends';
const _historyBackLabel = 'History';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key, this.onBackPressed});

  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final onBackPressed = this.onBackPressed;
    final leading = onBackPressed == null
        ? null
        : LabelledBackButton(
            onPressed: onBackPressed,
            label: _historyBackLabel,
          );

    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: const Text(_trendsTitle),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: const SizedBox.expand(),
    );
  }
}
