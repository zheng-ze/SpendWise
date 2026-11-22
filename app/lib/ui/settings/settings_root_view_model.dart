import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/step_emitting.dart';

// MARK: - Steps
sealed class SettingsStep {}

class CategoriesRequested extends SettingsStep {}

class RecycleBinRequested extends SettingsStep {}

// MARK: - SettingsRootViewState
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

// MARK: - SettingsRootViewModel
abstract class SettingsRootViewModel {
  void requestCategories();
  void requestRecycleBin();
  void clearStep();
}

// MARK: - SettingsRootNotifier
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
  void requestRecycleBin() => emitStep(RecycleBinRequested());
}

// MARK: - Constants
final settingsRootViewModelProvider =
    NotifierProvider.autoDispose<SettingsRootNotifier, SettingsRootViewState>(
      SettingsRootNotifier.new,
    );
