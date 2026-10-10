import 'package:flutter/material.dart';

import 'package:spendwise/ui/settings/settings_flow.dart';

class SettingsRoute extends MaterialPageRoute<void> {
  SettingsRoute({required String backLabel, required VoidCallback onEnded})
    : super(
        builder: (_) => SettingsFlow(backLabel: backLabel, onEnded: onEnded),
      );
}
