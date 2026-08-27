import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:spendwise/ocr/document_scanner_selection.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/document_crop_screen.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';
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
      child: Row(
        children: [
          if (!kIsWeb)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _scanWithNativeScanner(context),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scan receipt'),
              ),
            ),
          if (!kIsWeb) const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _uploadPhoto(context),
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Upload photo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanWithNativeScanner(BuildContext context) async {
    final scanner = selectDocumentScanner();
    if (scanner == null) {
      await _runScan(context, ReceiptScanSource.camera);
      return;
    }
    final bytes = await scanner.scanDocument();
    if (bytes == null) return;
    if (!context.mounted) return;
    await _runScan(
      context,
      ReceiptScanSource.camera,
      preCapturedBytes: bytes,
    );
  }

  Future<void> _uploadPhoto(BuildContext context) async {
    if (!kIsWeb) {
      await _runScan(context, ReceiptScanSource.gallery);
      return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => DocumentCropScreen(imageBytes: bytes),
      ),
    );
    if (cropped == null) return;
    if (!context.mounted) return;
    await _runScan(
      context,
      ReceiptScanSource.gallery,
      preCapturedBytes: cropped,
    );
  }

  Future<void> _runScan(
    BuildContext context,
    ReceiptScanSource source, {
    Uint8List? preCapturedBytes,
  }) async {
    _showLoadingDialog(context);
    ReceiptScanStop? stop;
    try {
      await runReceiptScan(
        source: source,
        controller: controller,
        preCapturedBytes: preCapturedBytes,
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
