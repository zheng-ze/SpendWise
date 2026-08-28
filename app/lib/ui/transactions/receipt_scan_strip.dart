import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan_flow.dart';

/// Hidden when the settings toggle is off. "Scan receipt" is iOS/Android
/// only; "Upload photo" is offered on every platform. Reads
/// [entryFormViewModelProvider] rather than taking a ViewModel instance
/// directly, since the scan/permission-denied outcome only ever surfaces
/// through that provider's state.
class ReceiptScanStrip extends ConsumerWidget {
  const ReceiptScanStrip({super.key, required this.formKey});

  final String? formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(scanStripEnabledProvider).value ?? true;
    if (!enabled) return const SizedBox.shrink();

    ref.listen(entryFormViewModelProvider(formKey), (previous, next) {
      final stop = next.value?.scanStop;
      if (stop == null) return;
      if (previous?.value?.scanStop == stop) return;
      _showPermissionDeniedMessage(context, stop);
      ref.read(entryFormViewModelProvider(formKey).notifier).clearScanStop();
    });

    final scanning = ref.watch(
      entryFormViewModelProvider(
        formKey,
      ).select((value) => value.value?.scanning ?? false),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              if (!kIsWeb)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: scanning ? null : () => _scan(ref),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Scan receipt'),
                  ),
                ),
              if (!kIsWeb) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: scanning ? null : () => _uploadPhoto(context, ref),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload photo'),
                ),
              ),
            ],
          ),
          if (scanning) ...[
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }

  void _scan(WidgetRef ref) {
    ref
        .read(entryFormViewModelProvider(formKey).notifier)
        .requestScan(ReceiptScanSource.camera);
  }

  Future<void> _uploadPhoto(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(entryFormViewModelProvider(formKey).notifier);
    if (!kIsWeb) {
      viewModel.requestScan(ReceiptScanSource.gallery);
      return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    viewModel.requestDocumentCrop(bytes);
  }

  void _showPermissionDeniedMessage(
    BuildContext context,
    ReceiptScanStop stop,
  ) {
    if (stop != ReceiptScanStop.permissionDenied) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera or photo library access was denied.'),
      ),
    );
  }
}
