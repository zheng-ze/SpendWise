import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class SettingsStep {}

class CategoriesRequested extends SettingsStep {}

class PlansRequested extends SettingsStep {}

class RecycleBinRequested extends SettingsStep {}

class SettingsRootViewState {
  const SettingsRootViewState({this.step});

  final SettingsStep? step;

  SettingsRootViewState copyWith({SettingsStep? Function()? step}) {
    return SettingsRootViewState(step: step == null ? this.step : step());
  }
}

abstract class SettingsRootViewModel {
  void requestCategories();
  void requestPlans();
  void requestRecycleBin();
  void clearStep();
}

class SettingsRootNotifier extends Notifier<SettingsRootViewState>
    implements SettingsRootViewModel {
  @override
  SettingsRootViewState build() => const SettingsRootViewState();

  @override
  void requestCategories() => _emitStep(CategoriesRequested());

  @override
  void requestPlans() => _emitStep(PlansRequested());

  @override
  void requestRecycleBin() => _emitStep(RecycleBinRequested());

  void _emitStep(SettingsStep step) => state = state.copyWith(step: () => step);

  @override
  void clearStep() => state = state.copyWith(step: () => null);
}

final settingsRootViewModelProvider =
    NotifierProvider<SettingsRootNotifier, SettingsRootViewState>(
      SettingsRootNotifier.new,
    );
