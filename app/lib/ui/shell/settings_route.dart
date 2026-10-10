import 'package:flutter/material.dart';

import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/shell/status_banner.dart';

class SettingsRoute extends MaterialPageRoute<void> {
  SettingsRoute({required String backLabel, required VoidCallback onEnded})
    : super(
        builder: (_) => Stack(
          fit: StackFit.expand,
          children: [
            SettingsFlow(backLabel: backLabel, onEnded: onEnded),
            const StatusBanner(),
          ],
        ),
      );
}
