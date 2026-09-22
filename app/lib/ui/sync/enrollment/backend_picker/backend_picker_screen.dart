import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

class BackendPickerScreen extends ConsumerStatefulWidget {
  const BackendPickerScreen({super.key});

  @override
  ConsumerState<BackendPickerScreen> createState() =>
      _BackendPickerScreenState();
}

class _BackendPickerScreenState extends ConsumerState<BackendPickerScreen> {
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
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Continue');
    void selectBackend(SyncBackendKind? backend) {
      if (backend != null) viewModel.selectBackend(backend);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose sync backend')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RadioGroup<SyncBackendKind>(
            groupValue: state.selectedBackend,
            onChanged: selectBackend,
            child: const Column(
              children: [
                _BackendOptionTile(
                  kind: SyncBackendKind.supabase,
                  title: 'Hosted sync',
                  subtitle: 'Sync through the managed SpendWise backend.',
                ),
                _BackendOptionTile(
                  kind: SyncBackendKind.custom,
                  title: 'Custom server',
                  subtitle: 'Sync through your own server over HTTPS.',
                ),
              ],
            ),
          ),
          if (isCustom)
            _CustomEndpointField(
              controller: _endpointController,
              errorText: state.endpointError,
              onChanged: viewModel.updateEndpoint,
            ),
          if (saveError != null) _PickerSaveError(message: saveError),
          const SizedBox(height: 16),
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
  });

  final SyncBackendKind kind;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<SyncBackendKind>(
      value: kind,
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _CustomEndpointField extends StatelessWidget {
  const _CustomEndpointField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: controller,
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(message, style: TextStyle(color: colors.error)),
    );
  }
}
