import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

// MARK: - StepListeningState
mixin StepListeningState<W extends ConsumerStatefulWidget, V, S extends Object>
    on ConsumerState<W> {
  ProviderListenable<AsyncValue<V>> get stepProvider;

  S? stepOf(V viewState);

  void clearStep();

  void handleStep(S step);

  ProviderSubscription<AsyncValue<V>>? _stepSubscription;

  @override
  void initState() {
    super.initState();
    _stepSubscription = ref.listenManual(stepProvider, (previous, next) {
      final viewState = next.value;
      if (viewState == null) return;
      _consumeStep(stepOf(viewState));
    });
  }

  @override
  void dispose() {
    _stepSubscription?.close();
    super.dispose();
  }

  void _consumeStep(S? step) {
    if (step == null) return;
    clearStep();
    handleStep(step);
  }
}
