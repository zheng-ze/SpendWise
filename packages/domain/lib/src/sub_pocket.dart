import 'package:domain/src/ids.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:meta/meta.dart';

@immutable
class SubPocket {
  SubPocket({
    String? id,
    required this.name,
    this.incomingTransfersAsExpenses = false,
    this.lifecycle = LifecycleState.active,
  }) : id = normalizedOrNewID(id);

  final String id;
  final String name;
  final bool incomingTransfersAsExpenses;
  final LifecycleState lifecycle;

  SubPocket settingLifecycle(LifecycleState lifecycle) {
    return SubPocket(
      id: id,
      name: name,
      incomingTransfersAsExpenses: incomingTransfersAsExpenses,
      lifecycle: lifecycle,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SubPocket &&
        other.id == id &&
        other.name == name &&
        other.incomingTransfersAsExpenses == incomingTransfersAsExpenses &&
        other.lifecycle == lifecycle;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, incomingTransfersAsExpenses, lifecycle);
}
