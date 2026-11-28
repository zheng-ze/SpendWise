import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'xlsx_sheet.dart';

const _workbookPath = 'xl/workbook.xml';
const _relsPath = 'xl/_rels/workbook.xml.rels';
const _sharedStringsPath = 'xl/sharedStrings.xml';
const _workbookDirectory = 'xl/';
const _absoluteTargetPrefix = '/';
const _anyNamespace = '*';
const _date1904Values = {'1', 'true'};
const _sharedStringType = 's';
const _inlineStringType = 'inlineStr';
const _letterBase = 26;
const _asciiCaseBit = 0x20;
const _asciiBeforeA = 96;
const _maxRowNumber = 1048576;
const _maxColumnNumber = 16384;
const _defaultMaxCells = 10000000;
final _columnLetters = RegExp('^[A-Za-z]+');

final class XlsxReader {
  const XlsxReader({this.maxCells = _defaultMaxCells});

  final int maxCells;

  XlsxSheet read(Uint8List bytes) {
    try {
      return _parse(bytes, maxCells);
    } on XlsxReadFailure {
      rethrow;
    } catch (error) {
      // archive and xml throw many unrelated types; every one must surface as
      // XlsxReadFailure with the cause kept.
      throw XlsxReadFailure('The file is not a readable xlsx.', cause: error);
    }
  }
}

XlsxSheet _parse(Uint8List bytes, int maxCells) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final workbook = _document(archive, _workbookPath);
  final rels = _document(archive, _relsPath);
  final sheetPath = _sheetPath(workbook, rels);
  final sheet = _document(archive, sheetPath);
  final sharedStrings = _sharedStrings(archive);
  final rows = _readRows(sheet, sharedStrings, maxCells);
  return XlsxSheet(rows: rows, date1904: _isDate1904(workbook));
}

Iterable<XmlElement> _descendants(XmlNode parent, String name) {
  return parent.findAllElements(name, namespaceUri: _anyNamespace);
}

Iterable<XmlElement> _children(XmlElement parent, String name) {
  return parent.findElements(name, namespaceUri: _anyNamespace);
}

List<List<String>> _readRows(
  XmlDocument sheet,
  List<String> sharedStrings,
  int maxCells,
) {
  final rows = <List<String>>[];
  var remainingCells = maxCells;
  for (final row in _descendants(sheet, 'row')) {
    final requested = int.tryParse(row.getAttribute('r') ?? '');
    if (requested != null && requested > _maxRowNumber) {
      throw XlsxReadFailure('Row $requested is beyond row $_maxRowNumber.');
    }
    final index = requested == null ? rows.length : requested - 1;
    final placedAt = index < rows.length ? rows.length : index;
    while (rows.length < placedAt) {
      rows.add(<String>[]);
    }
    final cells = _readRow(row, sharedStrings, remainingCells);
    remainingCells -= cells.length;
    rows.add(cells);
  }
  return rows;
}

XmlDocument _document(Archive archive, String path) {
  final file = archive.findFile(path);
  if (file == null) throw XlsxReadFailure('Missing part $path.');
  return XmlDocument.parse(utf8.decode(file.content));
}

bool _isDate1904(XmlDocument workbook) {
  final properties = _descendants(workbook, 'workbookPr').firstOrNull;
  return _date1904Values.contains(properties?.getAttribute('date1904'));
}

String _sheetPath(XmlDocument workbook, XmlDocument rels) {
  final sheet = _descendants(workbook, 'sheet').firstOrNull;
  if (sheet == null) throw const XlsxReadFailure('The workbook has no sheet.');
  final relationshipId = sheet.getAttribute('id', namespaceUri: _anyNamespace);
  final relationship = _descendants(rels, 'Relationship')
      .where((element) => element.getAttribute('Id') == relationshipId)
      .firstOrNull;
  final target = relationship?.getAttribute('Target');
  if (relationshipId == null || target == null) {
    throw const XlsxReadFailure('The sheet relationship is missing.');
  }
  if (target.startsWith(_absoluteTargetPrefix)) {
    return target.substring(_absoluteTargetPrefix.length);
  }
  return '$_workbookDirectory$target';
}

List<String> _sharedStrings(Archive archive) {
  if (archive.findFile(_sharedStringsPath) == null) return const [];
  final document = _document(archive, _sharedStringsPath);
  return [for (final item in _descendants(document, 'si')) _richText(item)];
}

String _richText(XmlElement element) {
  final texts = element.childElements.expand(_textElements);
  return texts.map((text) => text.innerText).join();
}

Iterable<XmlElement> _textElements(XmlElement element) {
  return switch (element.name.local) {
    't' => [element],
    'r' => _children(element, 't'),
    _ => const [],
  };
}

List<String> _readRow(
  XmlElement row,
  List<String> sharedStrings,
  int remainingCells,
) {
  final cells = <String>[];
  var nextColumn = 0;
  for (final cell in _children(row, 'c')) {
    final column = _column(cell.getAttribute('r')) ?? nextColumn;
    if (column >= remainingCells) {
      throw const XlsxReadFailure('The sheet has too many cells.');
    }
    while (cells.length <= column) {
      cells.add('');
    }
    cells[column] = _cellText(cell, sharedStrings);
    nextColumn = column + 1;
  }
  return cells;
}

int? _column(String? reference) {
  final letters = reference == null
      ? null
      : _columnLetters.stringMatch(reference);
  if (letters == null) return null;
  var number = 0;
  for (final unit in letters.codeUnits) {
    number = number * _letterBase + ((unit | _asciiCaseBit) - _asciiBeforeA);
    if (number > _maxColumnNumber) {
      throw XlsxReadFailure('Column $letters is beyond column $_maxColumnNumber.');
    }
  }
  return number - 1;
}

String _cellText(XmlElement cell, List<String> sharedStrings) {
  final type = cell.getAttribute('t');
  if (type == _inlineStringType) {
    final inline = _children(cell, 'is').firstOrNull;
    return inline == null ? '' : _richText(inline);
  }
  final value = _children(cell, 'v').firstOrNull?.innerText ?? '';
  if (type != _sharedStringType) return value;
  final index = int.tryParse(value);
  if (index == null || index < 0 || index >= sharedStrings.length) {
    throw XlsxReadFailure('Invalid shared string index "$value".');
  }
  return sharedStrings[index];
}
