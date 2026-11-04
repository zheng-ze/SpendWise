import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

// MARK: - Visual Constants

const _alertGap = 8.0;

// MARK: - EntryPaneLayout
class EntryPaneLayout extends StatelessWidget {
  const EntryPaneLayout({
    super.key,
    required this.body,
    required this.footer,
    this.inputSurface,
    this.alert,
    this.onAlertAction,
  });

  final Widget body;

  final Widget footer;

  final Widget? inputSurface;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  @override
  Widget build(BuildContext context) {
    final data = alert;
    final banner = data == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: _alertGap),
            child: SheetAlert(data: data, onAction: onAlertAction),
          );
    final surface = inputSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: SingleChildScrollView(child: body)),
        ?banner,
        footer,
        ?surface,
      ],
    );
  }
}
