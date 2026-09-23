import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

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
      _scanController(ref).clearScanStop();
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
    _scanController(ref).requestScan(ReceiptScanSource.camera);
  }

  void _uploadPhoto(WidgetRef ref) {
    _scanController(ref).requestScan(ReceiptScanSource.gallery);
  }

  ReceiptScanController _scanController(WidgetRef ref) =>
      ref.read(entryFormViewModelProvider(formKey).notifier);

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
