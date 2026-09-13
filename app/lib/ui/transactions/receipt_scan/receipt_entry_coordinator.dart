import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ocr/document_scanner_selection.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

/// Transient state for the receipt-scan / document-crop flow owned by the
/// coordinator. The ViewModel mirrors [scanning] / [scanStop] into its own
/// state so the View can keep reading them from there.
class ReceiptOrchestrationState {
  const ReceiptOrchestrationState({this.scanning = false, this.scanStop});

  /// True while a receipt scan is recognizing an image.
  final bool scanning;

  /// Set once by a scan that ended without prefilling anything, so the View
  /// can show why. Cleared the same single-shot way as the ViewModel's [step].
  final ReceiptScanStop? scanStop;

  ReceiptOrchestrationState copyWith({
    bool? scanning,
    ReceiptScanStop? Function()? scanStop,
  }) {
    return ReceiptOrchestrationState(
      scanning: scanning ?? this.scanning,
      scanStop: scanStop == null ? this.scanStop : scanStop(),
    );
  }
}

/// Owns the receipt-scan and document-crop orchestration and its transient
/// state. The [EntryFormNotifier] delegates [requestScan] / [applyCroppedDocument]
/// to it and mirrors [ReceiptOrchestrationState] into its own state.
class ReceiptEntryCoordinator extends Notifier<ReceiptOrchestrationState> {
  ReceiptEntryCoordinator([this.entryId]);

  /// The entry form this coordinator serves, if any. Available for
  /// diagnostics; orchestration itself does not depend on it.
  final String? entryId;

  @override
  ReceiptOrchestrationState build() => const ReceiptOrchestrationState();

  Future<void> requestScan(
    ReceiptScanSource source, {
    Uint8List? preCapturedBytes,
    required ScanResultHandler onPrefill,
  }) async {
    unawaited(_runScan(source, preCapturedBytes, onPrefill));
  }

  Future<void> applyCroppedDocument(
    Uint8List bytes, {
    required ScanResultHandler onPrefill,
  }) {
    return requestScan(
      ReceiptScanSource.gallery,
      preCapturedBytes: bytes,
      onPrefill: onPrefill,
    );
  }

  void clearScanStop() => state = state.copyWith(scanStop: () => null);

  Future<void> _runScan(
    ReceiptScanSource source,
    Uint8List? preCapturedBytes,
    ScanResultHandler onPrefill,
  ) async {
    state = state.copyWith(scanning: true);
    ReceiptScanStop? stop;
    try {
      if (source == ReceiptScanSource.camera && preCapturedBytes == null) {
        final capture = await _captureWithNativeScanner();
        switch (capture) {
          case _NativeScannerCancelled():
            // Unlike an unavailable scanner, this does not fall through to
            // the plain camera picker below.
            return;
          case _NativeScannerCaptured(:final bytes):
            await runReceiptScan(
              source: source,
              preCapturedBytes: bytes,
              onExtracted: onPrefill,
              onStop: (value) => stop = value,
            );
            return;
          case _NativeScannerUnavailable():
            break;
        }
      }

      await runReceiptScan(
        source: source,
        preCapturedBytes: preCapturedBytes,
        onExtracted: onPrefill,
        onStop: (value) => stop = value,
      );
    } finally {
      state = state.copyWith(scanning: false, scanStop: () => stop);
    }
  }

  // Unavailable means the caller should fall through to the plain camera
  // picker. Cancelled means no fallback should run.
  Future<_NativeScannerOutcome> _captureWithNativeScanner() async {
    final scanner = await selectDocumentScanner();
    if (scanner == null) return const _NativeScannerUnavailable();

    Uint8List? bytes;
    try {
      bytes = await scanner.scanDocument();
    } on PlatformException {
      // The scanner itself failed to launch (for example, Android with no
      // Google Play Services) rather than the user backing out of it.
      return const _NativeScannerUnavailable();
    }

    return bytes == null
        ? const _NativeScannerCancelled()
        : _NativeScannerCaptured(bytes);
  }
}

final receiptEntryCoordinatorProvider =
    NotifierProvider.family<
      ReceiptEntryCoordinator,
      ReceiptOrchestrationState,
      String?
    >(ReceiptEntryCoordinator.new);

sealed class _NativeScannerOutcome {
  const _NativeScannerOutcome();
}

class _NativeScannerUnavailable extends _NativeScannerOutcome {
  const _NativeScannerUnavailable();
}

class _NativeScannerCancelled extends _NativeScannerOutcome {
  const _NativeScannerCancelled();
}

class _NativeScannerCaptured extends _NativeScannerOutcome {
  const _NativeScannerCaptured(this.bytes);

  final Uint8List bytes;
}
