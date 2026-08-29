import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/step_emitting.dart';

sealed class SettingsStep {}

class CategoriesRequested extends SettingsStep {}

class PlansRequested extends SettingsStep {}

class RecycleBinRequested extends SettingsStep {}

class SettingsRootViewState
    implements HasStep<SettingsRootViewState, SettingsStep> {
  const SettingsRootViewState({this.step});

  @override
  final SettingsStep? step;

  SettingsRootViewState copyWith({SettingsStep? Function()? step}) {
    return SettingsRootViewState(step: step == null ? this.step : step());
  }

  @override
  SettingsRootViewState withStep(SettingsStep? Function() step) =>
      copyWith(step: step);
}

abstract class SettingsRootViewModel {
  void requestCategories();
  void requestPlans();
  void requestRecycleBin();
  void clearStep();
}

class SettingsRootNotifier extends Notifier<SettingsRootViewState>
    with StepEmitting<SettingsRootViewState, SettingsStep>
    implements SettingsRootViewModel {
  @override
  SettingsRootViewState build() => const SettingsRootViewState();

  @override
  void updateState(
    SettingsRootViewState Function(SettingsRootViewState current) apply,
  ) => state = apply(state);

  @override
  void requestCategories() => emitStep(CategoriesRequested());

  @override
  void requestPlans() => emitStep(PlansRequested());

  @override
  void requestRecycleBin() => emitStep(RecycleBinRequested());
}

final settingsRootViewModelProvider =
    NotifierProvider<SettingsRootNotifier, SettingsRootViewState>(
      SettingsRootNotifier.new,
    );
