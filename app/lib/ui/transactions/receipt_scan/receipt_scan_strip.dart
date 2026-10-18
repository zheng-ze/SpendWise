import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

// MARK: - ReceiptScanStrip
class ReceiptScanStrip extends ConsumerWidget {
  const ReceiptScanStrip({
    super.key,
    required this.formKey,
    this.compactActions = false,
  });

  final String? formKey;
  final bool compactActions;

  static const _stripBottomPadding = 16.0;
  static const _progressSpacing = 12.0;
  static const _compactVerticalPadding = 8.0;

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

    final scanButton = OutlinedButton.icon(
      onPressed: scanning ? null : () => _scan(ref),
      icon: const Icon(Icons.camera_alt_outlined),
      label: const Text('Scan receipt'),
    );
    final uploadButton = OutlinedButton.icon(
      onPressed: scanning ? null : () => _uploadPhoto(ref),
      icon: const Icon(Icons.upload_outlined),
      label: const Text('Upload photo'),
    );
    final actions = _StripActions(
      scanButton: scanButton,
      uploadButton: uploadButton,
      stackWhenCramped: compactActions,
    );
    final padding = compactActions
        ? const EdgeInsets.symmetric(vertical: _compactVerticalPadding)
        : const EdgeInsets.only(bottom: _stripBottomPadding);

    return Padding(
      padding: padding,
      child: Column(
        children: [
          actions,
          if (scanning) ...[
            const SizedBox(height: _progressSpacing),
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

// MARK: - StripActions
class _StripActions extends StatelessWidget {
  const _StripActions({
    required this.scanButton,
    required this.uploadButton,
    required this.stackWhenCramped,
  });

  final Widget scanButton;
  final Widget uploadButton;
  final bool stackWhenCramped;

  static const _scanLabel = 'Scan receipt';
  static const _uploadLabel = 'Upload photo';
  static const _buttonSpacing = 12.0;
  static const _buttonIconSize = 18.0;
  static const _buttonIconGap = 8.0;
  static const _buttonHorizontalPadding = 28.0;

  @override
  Widget build(BuildContext context) {
    final sideBySide = Row(
      children: [
        Expanded(child: scanButton),
        const SizedBox(width: _buttonSpacing),
        Expanded(child: uploadButton),
      ],
    );
    if (!stackWhenCramped) return sideBySide;

    final stacked = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scanButton,
        const SizedBox(height: _buttonSpacing),
        uploadButton,
      ],
    );
    final style = Theme.of(context).textTheme.labelLarge;
    final labelWidth = math.max(
      _textWidth(context, _scanLabel, style),
      _textWidth(context, _uploadLabel, style),
    );
    final buttonWidth =
        labelWidth +
        _buttonIconSize +
        _buttonIconGap +
        _buttonHorizontalPadding;
    final rowWidth = 2 * buttonWidth + _buttonSpacing;

    return LayoutBuilder(
      builder: (context, constraints) =>
          rowWidth <= constraints.maxWidth ? sideBySide : stacked,
    );
  }

  static double _textWidth(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
