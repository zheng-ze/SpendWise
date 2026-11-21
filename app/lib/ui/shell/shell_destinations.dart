import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Destination Labels
const destinationLabels = {
  ShellDestination.overview: 'Overview',
  ShellDestination.history: 'History',
  ShellDestination.money: 'Money',
  ShellDestination.settings: 'Settings',
};

// MARK: - Destination Icons
const destinationIcons = {
  ShellDestination.overview: Icons.home_outlined,
  ShellDestination.history: Icons.history_outlined,
  ShellDestination.money: Icons.account_balance_wallet_outlined,
  ShellDestination.settings: Icons.settings_outlined,
};
