import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class ImportFilePicker {
  Future<Uint8List?> pick();
}

const excelWorkbookTypeGroup = XTypeGroup(
  label: 'Excel workbook',
  extensions: ['xlsx'],
  mimeTypes: [
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ],
  uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet'],
);

class FileSelectorImportFilePicker implements ImportFilePicker {
  const FileSelectorImportFilePicker();

  @override
  Future<Uint8List?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [excelWorkbookTypeGroup],
    );
    if (file == null) {
      return null;
    }
    return file.readAsBytes();
  }
}

final importFilePickerProvider = Provider<ImportFilePicker>(
  (ref) => const FileSelectorImportFilePicker(),
);
