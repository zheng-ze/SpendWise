import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';

class ReceiptScanStopHost extends ConsumerWidget {
  const ReceiptScanStopHost({super.key, required this.formKey});

  final String? formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(entryFormViewModelProvider(formKey), (previous, next) {
      final stop = next.value?.scanStop;
      if (stop == null) return;
      if (previous?.value?.scanStop == stop) return;
      _showPermissionDeniedMessage(context, stop);
      final controller = ref.read(entryFormViewModelProvider(formKey).notifier);
      controller.clearScanStop();
    });
    return const SizedBox.shrink();
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
