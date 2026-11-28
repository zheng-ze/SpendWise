import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const List<String> moneyManagerHeader = [
  'Date',
  'Account',
  'Category',
  'Subcategory',
  'Note',
  'SGD',
  'Income/Expense',
  'Tag',
  'Description',
  'Amount',
  'Currency',
  'Account',
];

const double defaultMoneyManagerDateSerial = 46352.970728506945;

const String contentTypesPart = '[Content_Types].xml';
const String rootRelsPart = '_rels/.rels';
const String workbookPart = 'xl/workbook.xml';
const String workbookRelsPart = 'xl/_rels/workbook.xml.rels';
const String sharedStringsPart = 'xl/sharedStrings.xml';
const String sheetPart = 'xl/worksheets/sheet1.xml';

const String _xmlDeclaration =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const String _mainNamespace =
    'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const String _relsNamespace =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const String _officeRelsNamespace =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const int _firstColumnCode = 65;

/// A row cell is a [String] (shared-string text) or a [num] (numeric cell).
/// An empty string leaves the cell out.
List<Object> moneyManagerRow({
  num date = defaultMoneyManagerDateSerial,
  String account = 'Cash',
  String category = 'Food',
  String subcategory = 'Lunch',
  String note = 'Note',
  String sgd = '2.0',
  String type = 'Expense',
  String description = 'Description',
  String tag = '',
  String amount = '2.0',
  String currency = 'SGD',
  String? duplicateAccount,
}) {
  return [
    date,
    account,
    category,
    subcategory,
    note,
    sgd,
    type,
    tag,
    description,
    amount,
    currency,
    duplicateAccount ?? account,
  ];
}

List<List<Object>> defaultMoneyManagerRows() {
  return [
    moneyManagerRow(),
    moneyManagerRow(
      date: 46353.5,
      account: 'Bank',
      category: 'Salary',
      subcategory: '',
      type: 'Income',
      sgd: '1046.65',
      amount: '1046.65',
    ),
  ];
}

/// [partOverrides] values are a [String] or a [List<int>]; [removedParts]
/// names zip entries to leave out.
Uint8List buildMoneyManagerXlsx({
  List<List<Object>>? rows,
  bool date1904 = false,
  Map<String, Object> partOverrides = const {},
  Set<String> removedParts = const {},
}) {
  final dataRows = rows ?? defaultMoneyManagerRows();
  final parts = <String, Object>{
    ..._defaultParts(date1904),
    ..._sheetParts([moneyManagerHeader, ...dataRows]),
    ...partOverrides,
  };
  removedParts.forEach(parts.remove);
  return _zip(parts);
}

Uint8List _zip(Map<String, Object> parts) {
  final archive = Archive();
  for (final entry in parts.entries) {
    archive.addFile(_archiveFile(entry.key, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

ArchiveFile _archiveFile(String name, Object content) {
  if (content is String) return ArchiveFile.string(name, content);
  return ArchiveFile.bytes(name, content as List<int>);
}

Map<String, String> _defaultParts(bool date1904) {
  return {
    contentTypesPart: _contentTypesXml(),
    rootRelsPart: _rootRelsXml(),
    workbookPart: _workbookXml(date1904),
    workbookRelsPart: _workbookRelsXml(),
  };
}

Map<String, String> _sheetParts(List<List<Object>> allRows) {
  final strings = <String>[];
  final sheet = _sheetXml(allRows, strings);
  return {sheetPart: sheet, sharedStringsPart: _sharedStringsXml(strings)};
}

String _contentTypesXml() {
  return '$_xmlDeclaration'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
      '</Types>';
}

String _rootRelsXml() {
  return '$_xmlDeclaration'
      '<Relationships xmlns="$_relsNamespace">'
      '<Relationship Id="rId1" Type="$_officeRelsNamespace/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';
}

String _workbookXml(bool date1904) {
  return '$_xmlDeclaration'
      '<workbook xmlns="$_mainNamespace" xmlns:r="$_officeRelsNamespace">'
      '<workbookPr date1904="$date1904"/>'
      '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';
}

String _workbookRelsXml() {
  return '$_xmlDeclaration'
      '<Relationships xmlns="$_relsNamespace">'
      '<Relationship Id="rId1" Type="$_officeRelsNamespace/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="$_officeRelsNamespace/sharedStrings" Target="sharedStrings.xml"/>'
      '</Relationships>';
}

String _sharedStringsXml(List<String> strings) {
  final items = strings.map(_sharedStringItem).join();
  return '$_xmlDeclaration'
      '<sst xmlns="$_mainNamespace" count="${strings.length}" uniqueCount="${strings.length}">'
      '$items</sst>';
}

String _sharedStringItem(String text) {
  return '<si><t xml:space="preserve">${escapeXml(text)}</t></si>';
}

String _sheetXml(List<List<Object>> allRows, List<String> strings) {
  final rowsXml = StringBuffer();
  for (var i = 0; i < allRows.length; i++) {
    rowsXml.write(_rowXml(i + 1, allRows[i], strings));
  }
  return '$_xmlDeclaration'
      '<worksheet xmlns="$_mainNamespace">'
      '<dimension ref="A1"/>'
      '<sheetData>$rowsXml</sheetData>'
      '</worksheet>';
}

String _rowXml(int rowNumber, List<Object> cells, List<String> strings) {
  final cellsXml = StringBuffer();
  for (var i = 0; i < cells.length; i++) {
    final ref = '${String.fromCharCode(_firstColumnCode + i)}$rowNumber';
    cellsXml.write(_cellXml(ref, cells[i], strings));
  }
  return '<row r="$rowNumber">$cellsXml</row>';
}

String _cellXml(String ref, Object value, List<String> strings) {
  if (value is num) return '<c r="$ref"><v>$value</v></c>';
  final text = value as String;
  if (text.isEmpty) return '';
  strings.add(text);
  return '<c r="$ref" t="s"><v>${strings.length - 1}</v></c>';
}

String escapeXml(String text) {
  return const HtmlEscape(HtmlEscapeMode.attribute).convert(text);
}
