import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';
import 'package:spendwise/ui/transactions/prototype_boundary_overlay.dart';
import 'package:spendwise/ui/transactions/receipt_scan_flow.dart';

/// Hidden when the settings toggle is off. "Scan receipt" is iOS/Android
/// only; "Upload photo" is offered on every platform.
class ReceiptScanStrip extends ConsumerWidget {
  const ReceiptScanStrip({super.key, required this.controller});

  final EntryFormController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(scanStripEnabledProvider).value ?? true;
    if (!enabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!kIsWeb)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _runScan(context, ReceiptScanSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Scan receipt'),
                  ),
                ),
              if (!kIsWeb) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _runScan(context, ReceiptScanSource.gallery),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload photo'),
                ),
              ),
            ],
          ),
          _prototypeLauncher(context),
        ],
      ),
    );
  }

  // PROTOTYPE-only launcher for issue #20, deliberately left off the real
  // row above. Remove once the prototype is captured and this ticket closes.
  Widget _prototypeLauncher(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PrototypeBoundaryOverlayScreen(),
          ),
        ),
        child: const Text('Prototype: boundary overlay (#20)'),
      ),
    );
  }

  Future<void> _runScan(BuildContext context, ReceiptScanSource source) async {
    _showLoadingDialog(context);
    ReceiptScanStop? stop;
    try {
      await runReceiptScan(
        source: source,
        controller: controller,
        onStop: (value) => stop = value,
      );
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (context.mounted && stop == ReceiptScanStop.permissionDenied) {
      _showPermissionDeniedMessage(context, source);
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showPermissionDeniedMessage(
    BuildContext context,
    ReceiptScanSource source,
  ) {
    final subject = source == ReceiptScanSource.camera
        ? 'Camera'
        : 'Photo library';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$subject access was denied.')));
  }
}
