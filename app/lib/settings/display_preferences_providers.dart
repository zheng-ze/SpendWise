import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_store.dart';

final initialDisplayPreferencesProvider = Provider<DisplayPreferences>(
  (ref) => DisplayPreferences.defaults,
);

final displayPreferencesProvider =
    NotifierProvider<DisplayPreferencesNotifier, DisplayPreferences>(
      DisplayPreferencesNotifier.new,
    );

class DisplayPreferencesNotifier extends Notifier<DisplayPreferences> {
  @override
  DisplayPreferences build() => ref.watch(initialDisplayPreferencesProvider);

  Future<void> replace(DisplayPreferences next) async {
    state = next;
    try {
      await DisplayPreferencesStore(await SharedPreferences.getInstance())
          .save(next);
    } catch (error, stackTrace) {
      debugPrint('Display preferences write failed: $error\n$stackTrace');
    }
  }
}
