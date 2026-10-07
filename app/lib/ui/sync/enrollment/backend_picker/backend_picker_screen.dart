import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

class BackendPickerScreen extends ConsumerStatefulWidget {
  const BackendPickerScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<BackendPickerScreen> createState() =>
      _BackendPickerScreenState();
}

class _BackendPickerScreenState extends ConsumerState<BackendPickerScreen> {
  static const _screenPadding = EdgeInsets.all(16);
  static const _continueGap = 16.0;
  static const _progressIndicatorSize = 20.0;
  static const _progressStrokeWidth = 2.0;

  late final TextEditingController _endpointController =
      TextEditingController();

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BackendPickerViewModel viewModel = ref.watch(
      backendPickerViewModelProvider.notifier,
    );
    final BackendPickerState state = ref.watch(backendPickerViewModelProvider);
    final saveError = state.saveError;
    final isCustom = state.selectedBackend == SyncBackendKind.custom;
    final continueButton = state.saving
        ? const SizedBox.square(
            dimension: _progressIndicatorSize,
            child: CircularProgressIndicator(strokeWidth: _progressStrokeWidth),
          )
        : const Text('Continue');
    void selectBackend(SyncBackendKind? backend) {
      if (backend != null) viewModel.selectBackend(backend);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose sync backend'),
        // BackButton cannot be disabled (a null onPressed falls back to
        // maybePop), so use an IconButton to hold the disabled state.
        leading: widget.onBack == null
            ? null
            : IconButton(
                key: const Key('syncPickerBack'),
                icon: const BackButtonIcon(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: state.saving ? null : widget.onBack,
              ),
      ),
      body: ListView(
        padding: _screenPadding,
        children: [
          RadioGroup<SyncBackendKind>(
            groupValue: state.selectedBackend,
            onChanged: selectBackend,
            child: Column(
              children: [
                _BackendOptionTile(
                  kind: SyncBackendKind.supabase,
                  title: 'Hosted sync',
                  subtitle: 'Sync through the managed SpendWise backend.',
                  enabled: !state.saving,
                ),
                _BackendOptionTile(
                  kind: SyncBackendKind.custom,
                  title: 'Custom server',
                  subtitle: 'Sync through your own server over HTTPS.',
                  enabled: !state.saving,
                ),
              ],
            ),
          ),
          if (isCustom)
            _CustomEndpointField(
              controller: _endpointController,
              errorText: state.endpointError,
              onChanged: viewModel.updateEndpoint,
              enabled: !state.saving,
            ),
          if (saveError != null) _PickerSaveError(message: saveError),
          const SizedBox(height: _continueGap),
          FilledButton(
            onPressed: state.saving ? null : viewModel.continueWithSelection,
            child: continueButton,
          ),
        ],
      ),
    );
  }
}

class _BackendOptionTile extends StatelessWidget {
  const _BackendOptionTile({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.enabled = true,
  });

  final SyncBackendKind kind;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<SyncBackendKind>(
      value: kind,
      title: Text(title),
      subtitle: Text(subtitle),
      enabled: enabled,
    );
  }
}

class _CustomEndpointField extends StatelessWidget {
  const _CustomEndpointField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const _fieldPadding = EdgeInsets.fromLTRB(16, 0, 16, 8);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _fieldPadding,
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: 'Server URL',
          hintText: 'https://sync.example.com',
          errorText: errorText,
        ),
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: onChanged,
      ),
    );
  }
}

class _PickerSaveError extends StatelessWidget {
  const _PickerSaveError({required this.message});

  final String message;

  static const _errorPadding = EdgeInsets.fromLTRB(16, 8, 16, 0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: _errorPadding,
      child: Text(message, style: TextStyle(color: colors.error)),
    );
  }
}
