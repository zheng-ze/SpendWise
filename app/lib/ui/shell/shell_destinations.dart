import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Destination Labels
const destinationLabels = {
  ShellDestination.overview: 'Overview',
  ShellDestination.history: 'History',
  ShellDestination.trends: 'Trends',
  ShellDestination.money: 'Money',
  ShellDestination.settings: 'Settings',
};

// MARK: - Destination Icons
const destinationIcons = {
  ShellDestination.overview: Icons.home_outlined,
  ShellDestination.history: Icons.history_outlined,
  ShellDestination.trends: Icons.pie_chart_outline,
  ShellDestination.money: Icons.account_balance_wallet_outlined,
  ShellDestination.settings: Icons.settings_outlined,
};

// MARK: - Destination Weights
const selectedDestinationWeight = FontWeight.w600;

const unselectedDestinationWeight = FontWeight.w500;
