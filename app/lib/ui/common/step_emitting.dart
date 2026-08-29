/// Implemented by a ViewState that carries a one-shot navigation [Step],
/// so [StepEmitting] can emit and clear it without knowing the rest of the
/// ViewState's shape. `T` is the implementing ViewState itself, so
/// `withStep` can return it without a cast.
abstract interface class HasStep<T, S> {
  S? get step;
  T withStep(S? Function() step);
}

/// Shared `emitStep`/`clearStep` pair for a notifier whose state is a
/// [HasStep], regardless of whether it is built on `Notifier` or
/// `AsyncNotifier`. `updateState` is the seam: `LedgerBackedNotifier`
/// supplies the `AsyncNotifier` version, and a plain-`Notifier` ViewModel
/// supplies its own.
mixin StepEmitting<T extends HasStep<T, S>, S> {
  void updateState(T Function(T current) apply);

  void emitStep(S step) => updateState((current) => current.withStep(() => step));

  void clearStep() => updateState((current) => current.withStep(() => null));
}
