import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/persistence/database_connection.dart';

enum ShellDestination { transactions, stats, accounts, settings }

final selectedDestinationProvider = StateProvider<ShellDestination>(
  (ref) => ShellDestination.transactions,
);

DateTime startOfMonthUtc(DateTime date) => DateTime.utc(date.year, date.month);

/// The month currently selected for scoped views, starting as the current
/// month.
// Held in a provider rather than the shell widget's state, so a rebuild of
// the shell cannot reset the user's choice.
final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => startOfMonthUtc(DateTime.now()),
);

/// [storageIsDurable] is set while the connection opens, so this only carries
/// an answer once boot has resolved the database.
final storageIsDurableProvider = Provider<bool>((ref) => storageIsDurable);
