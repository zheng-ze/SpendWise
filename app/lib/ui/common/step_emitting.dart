abstract interface class HasStep<T, S> {
  S? get step;
  T withStep(S? Function() step);
}

mixin StepEmitting<T extends HasStep<T, S>, S> {
  void updateState(T Function(T current) apply);

  void emitStep(S step) =>
      updateState((current) => current.withStep(() => step));

  void clearStep() => updateState((current) => current.withStep(() => null));
}
