import 'package:flutter_riverpod/flutter_riverpod.dart';

// MARK: - IdSelectionNotifier
class IdSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;

  void clear() => state = null;
}
