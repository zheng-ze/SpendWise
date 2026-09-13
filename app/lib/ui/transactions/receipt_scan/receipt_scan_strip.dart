import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

/// Hidden when the settings toggle is off. "Scan receipt" and "Upload photo"
/// both render on every platform. If no recognizer is available, the scan
/// resolves to an empty result and extraction falls back to a blank
/// manual-entry draft. Denied permissions and cancelled pickers are handled
/// by the scan flow and the receipt entry coordinator, which record the stop
/// reason for the view to show.
class ReceiptScanStrip extends ConsumerWidget {
  const ReceiptScanStrip({super.key, required this.formKey});

  final String? formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(scanStripEnabledProvider).value ?? true;
    if (!enabled) return const SizedBox.shrink();

    // Listens on the provider instead of taking a ViewModel directly, since
    // only the provider's state carries the scan/permission-denied outcome.
    ref.listen(entryFormViewModelProvider(formKey), (previous, next) {
      final stop = next.value?.scanStop;
      if (stop == null) return;
      if (previous?.value?.scanStop == stop) return;
      _showPermissionDeniedMessage(context, stop);
      ref.read(entryFormViewModelProvider(formKey).notifier).clearScanStop();
    });

    final scanning = ref.watch(
      entryFormViewModelProvider(formKey)
          .select((value) => value.value?.scanning ?? false),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: scanning ? null : () => _scan(ref),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan receipt'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: scanning ? null : () => _uploadPhoto(ref),
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

  void _uploadPhoto(WidgetRef ref) {
    ref
        .read(entryFormViewModelProvider(formKey).notifier)
        .requestScan(ReceiptScanSource.gallery);
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
