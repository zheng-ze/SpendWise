import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/import/xlsx/xlsx_reader.dart';
import 'package:spendwise/import/xlsx/xlsx_sheet.dart';

import '../support/xlsx_fixture.dart';

const _mainNamespace =
    'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _relsNamespace =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const _officeRelsNamespace =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _reader = XlsxReader();

String _sheetXml(String rowsXml) {
  return '<worksheet xmlns="$_mainNamespace">'
      '<dimension ref="A1"/><sheetData>$rowsXml</sheetData></worksheet>';
}

String _sharedStringsXml(String itemsXml) {
  return '<sst xmlns="$_mainNamespace">$itemsXml</sst>';
}

String _workbookXml(String sheetsXml) {
  return '<workbook xmlns="$_mainNamespace" xmlns:r="$_officeRelsNamespace">'
      '<sheets>$sheetsXml</sheets></workbook>';
}

String _relsXml(String relationshipsXml) {
  return '<Relationships xmlns="$_relsNamespace">$relationshipsXml'
      '</Relationships>';
}

XlsxSheet _readSheet(String rowsXml, {String? sharedStrings}) {
  final overrides = <String, Object>{
    sheetPart: _sheetXml(rowsXml),
    sharedStringsPart: ?sharedStrings,
  };
  final bytes = buildMoneyManagerXlsx(partOverrides: overrides);
  return _reader.read(bytes);
}

TypeMatcher<XlsxReadFailure> _readFailure([String? messagePart]) {
  final failure = isA<XlsxReadFailure>();
  if (messagePart == null) return failure;
  return failure.having(
    (error) => error.message,
    'message',
    contains(messagePart),
  );
}

void _expectFailure(Uint8List bytes, [String? messagePart]) {
  expect(() => _reader.read(bytes), throwsA(_readFailure(messagePart)));
}

void main() {
  group('cell types', () {
    test('reads shared strings and numbers from a generated export', () {
      final bytes = buildMoneyManagerXlsx(
        rows: [moneyManagerRow(date: 46352.5, note: 'a & b')],
      );

      final sheet = _reader.read(bytes);

      expect(sheet.rows.first, moneyManagerHeader);
      expect(sheet.rows[1].first, '46352.5');
      expect(sheet.rows[1][4], 'a & b');
    });

    test('a wrong dimension ref is ignored', () {
      final bytes = buildMoneyManagerXlsx();

      final sheet = _reader.read(bytes);

      expect(sheet.rows, hasLength(3));
    });

    test('joins rich-text runs and skips phonetic text', () {
      const items =
          '<si><r><t>Foo</t></r><r><rPr/><t>Bar</t></r>'
          '<rPh sb="0"><t>skip</t></rPh></si>'
          '<si><t>Baz</t><rPh sb="0"><t>skip</t></rPh><phoneticPr/></si>';
      const row =
          '<row r="1"><c r="A1" t="s"><v>0</v></c>'
          '<c r="B1" t="s"><v>1</v></c></row>';

      final sheet = _readSheet(row, sharedStrings: _sharedStringsXml(items));

      expect(sheet.rows.single, ['FooBar', 'Baz']);
    });

    test('reads inline strings, including one with no text', () {
      const row =
          '<row r="1"><c r="A1" t="inlineStr"><is><t>Hi</t></is></c>'
          '<c r="B1" t="inlineStr"/></row>';

      final sheet = _readSheet(row);

      expect(sheet.rows.single, ['Hi', '']);
    });

    test('reads t="str" cells as their raw value', () {
      const row = '<row r="1"><c r="A1" t="str"><v>1.50</v></c></row>';

      final sheet = _readSheet(row);

      expect(sheet.rows.single, ['1.50']);
    });

    test('keeps number text raw and gives a cell with no value ""', () {
      const row =
          '<row r="1"><c r="A1"><v>46352.970728506945</v></c>'
          '<c r="B1"/></row>';

      final sheet = _readSheet(row);

      expect(sheet.rows.single, ['46352.970728506945', '']);
    });
  });

  group('cell placement', () {
    test('a gap between cells becomes empty strings', () {
      const row =
          '<row r="1"><c r="A1"><v>1</v></c><c r="D1"><v>4</v></c></row>';

      final sheet = _readSheet(row);

      expect(sheet.rows.single, ['1', '', '', '4']);
    });

    test('multi-letter and lowercase column letters are placed', () {
      const row = '<row r="1"><c r="aa1"><v>27</v></c></row>';

      final sheet = _readSheet(row);

      expect(sheet.rows.single, hasLength(27));
      expect(sheet.rows.single.last, '27');
    });

    test('a cell without r takes the next column', () {
      const row =
          '<row r="1"><c r="B1"><v>2</v></c><c><v>3</v></c>'
          '<c r="1"><v>4</v></c></row>';

      final sheet = _readSheet(row);

      expect(sheet.rows.single, ['', '2', '3', '4']);
    });

    test('an empty row gives an empty list', () {
      final sheet = _readSheet('<row r="1"/>');

      expect(sheet.rows.single, isEmpty);
    });
  });

  group('row placement', () {
    test('rows omitted by r leave empty rows between', () {
      const rows =
          '<row r="1"><c r="A1"><v>1</v></c></row>'
          '<row r="4"><c r="A4"><v>4</v></c></row>';

      final sheet = _readSheet(rows);

      expect(sheet.rows, [
        ['1'],
        <String>[],
        <String>[],
        ['4'],
      ]);
    });

    test('a leading gap and a row without r take the next index', () {
      const rows =
          '<row r="3"><c r="A3"><v>3</v></c></row>'
          '<row><c><v>4</v></c></row>'
          '<row r="x"><c><v>5</v></c></row>';

      final sheet = _readSheet(rows);

      expect(sheet.rows, [
        <String>[],
        <String>[],
        ['3'],
        ['4'],
        ['5'],
      ]);
    });

    test('a duplicate or out-of-order r takes the next index', () {
      const rows =
          '<row r="2"><c><v>a</v></c></row>'
          '<row r="2"><c><v>b</v></c></row>'
          '<row r="1"><c><v>c</v></c></row>'
          '<row r="0"><c><v>d</v></c></row>';

      final sheet = _readSheet(rows);

      expect(sheet.rows, [
        <String>[],
        ['a'],
        ['b'],
        ['c'],
        ['d'],
      ]);
    });
  });

  group('prefixed spreadsheetML', () {
    test('reads rows, cells, values and inline strings', () {
      const prefixedSheet =
          '<x:worksheet xmlns:x="$_mainNamespace"><x:sheetData>'
          '<x:row r="1"><x:c r="A1"><x:v>7</x:v></x:c>'
          '<x:c r="B1" t="inlineStr"><x:is><x:t>Hi</x:t></x:is></x:c>'
          '<x:c r="C1" t="s"><x:v>0</x:v></x:c></x:row>'
          '</x:sheetData></x:worksheet>';
      const sharedStrings =
          '<x:sst xmlns:x="$_mainNamespace">'
          '<x:si><x:r><x:t>Rich</x:t></x:r><x:r><x:t>Text</x:t></x:r></x:si>'
          '</x:sst>';
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {
          sheetPart: prefixedSheet,
          sharedStringsPart: sharedStrings,
        },
      );

      final sheet = _reader.read(bytes);

      expect(sheet.rows.single, ['7', 'Hi', 'RichText']);
    });

    test('reads a prefixed workbook and relationships', () {
      final workbook =
          '<x:workbook xmlns:x="$_mainNamespace" '
          'xmlns:r="$_officeRelsNamespace"><x:workbookPr date1904="1"/>'
          '<x:sheets><x:sheet name="S" r:id="rId1"/></x:sheets></x:workbook>';
      final rels =
          '<p:Relationships xmlns:p="$_relsNamespace">'
          '<p:Relationship Id="rId1" Type="worksheet" '
          'Target="worksheets/sheet1.xml"/></p:Relationships>';
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {workbookPart: workbook, workbookRelsPart: rels},
      );

      final sheet = _reader.read(bytes);

      expect(sheet.rows.first, moneyManagerHeader);
      expect(sheet.date1904, isTrue);
    });
  });

  group('workbook structure', () {
    test('resolves a relative rels target', () {
      final sheet = _reader.read(buildMoneyManagerXlsx());

      expect(sheet.rows.first, moneyManagerHeader);
    });

    test('resolves an absolute rels target', () {
      final rels = _relsXml(
        '<Relationship Id="rId1" Type="worksheet" '
        'Target="/xl/worksheets/sheet1.xml"/>',
      );
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {workbookRelsPart: rels},
      );

      final sheet = _reader.read(bytes);

      expect(sheet.rows.first, moneyManagerHeader);
    });

    test('date1904 true is read', () {
      final sheet = _reader.read(buildMoneyManagerXlsx(date1904: true));

      expect(sheet.date1904, isTrue);
    });

    test('date1904 false is read', () {
      final sheet = _reader.read(buildMoneyManagerXlsx());

      expect(sheet.date1904, isFalse);
    });

    test('a missing workbookPr means date1904 false', () {
      final workbook = _workbookXml(
        '<sheet name="Sheet1" sheetId="1" r:id="rId1"/>',
      );
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {workbookPart: workbook},
      );

      expect(_reader.read(bytes).date1904, isFalse);
    });

    test('a missing sharedStrings part is fine when no cell uses it', () {
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {
          sheetPart: _sheetXml('<row r="1"><c r="A1"><v>7</v></c></row>'),
        },
        removedParts: {sharedStringsPart},
      );

      expect(_reader.read(bytes).rows.single, ['7']);
    });
  });

  group('failures', () {
    test('bytes that are not a zip', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      expect(() => _reader.read(bytes), throwsA(_readFailure()));
    });

    test('malformed XML keeps the parser error as the cause', () {
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {sheetPart: '<worksheet><sheetData>'},
      );

      final failure = _readFailure().having(
        (error) => error.cause,
        'cause',
        isNotNull,
      );
      expect(() => _reader.read(bytes), throwsA(failure));
    });

    test('a missing workbook part', () {
      final bytes = buildMoneyManagerXlsx(removedParts: {workbookPart});

      _expectFailure(bytes, workbookPart);
    });

    test('a missing rels part', () {
      final bytes = buildMoneyManagerXlsx(removedParts: {workbookRelsPart});

      _expectFailure(bytes, workbookRelsPart);
    });

    test('a missing sheet part', () {
      final bytes = buildMoneyManagerXlsx(removedParts: {sheetPart});

      _expectFailure(bytes, sheetPart);
    });

    test('a workbook without a sheet', () {
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {workbookPart: _workbookXml('')},
      );

      _expectFailure(bytes, 'no sheet');
    });

    test('a sheet whose relationship is missing', () {
      final workbook = _workbookXml('<sheet name="S" r:id="rId9"/>');
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {workbookPart: workbook},
      );

      _expectFailure(bytes, 'relationship');
    });

    test('a sheet without a relationship id', () {
      final workbook = _workbookXml('<sheet name="S" sheetId="1"/>');
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {workbookPart: workbook},
      );

      _expectFailure(bytes, 'relationship');
    });

    test('a shared string reference with no sharedStrings part', () {
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {
          sheetPart: _sheetXml('<row r="1"><c r="A1" t="s"><v>0</v></c></row>'),
        },
        removedParts: {sharedStringsPart},
      );

      _expectFailure(bytes, 'shared string');
    });

    test('a non-integer shared string value', () {
      const row = '<row r="1"><c r="A1" t="s"><v>abc</v></c></row>';

      expect(() => _readSheet(row), throwsA(_readFailure('abc')));
    });

    test('a shared string cell with no value', () {
      const row = '<row r="1"><c r="A1" t="s"/></row>';

      expect(() => _readSheet(row), throwsA(_readFailure('shared string')));
    });

    test('an out-of-range shared string index', () {
      const row = '<row r="1"><c r="A1" t="s"><v>999</v></c></row>';

      expect(() => _readSheet(row), throwsA(_readFailure('999')));
    });

    test('a row number above the Excel maximum', () {
      const row = '<row r="1048577"/>';

      expect(() => _readSheet(row), throwsA(_readFailure('1048577')));
    });

    test('a row number at the Excel maximum is accepted', () {
      final sheet = _readSheet('<row r="1048576"/>');

      expect(sheet.rows, hasLength(1048576));
    });

    test('a column above the Excel maximum', () {
      const row = '<row r="1"><c r="XFE1"><v>1</v></c></row>';

      expect(() => _readSheet(row), throwsA(_readFailure('XFE')));
    });

    test('a very long column letter run fails without overflowing', () {
      final row = '<row r="1"><c r="${'Z' * 5000}1"><v>1</v></c></row>';

      expect(() => _readSheet(row), throwsA(_readFailure('beyond column')));
    });

    test('a sheet over the cell cap fails before filling gaps', () {
      const reader = XlsxReader(maxCells: 10);
      const rows =
          '<row r="1"><c r="D1"><v>1</v></c></row>'
          '<row r="2"><c r="D2"><v>1</v></c></row>'
          '<row r="3"><c r="D3"><v>1</v></c></row>';
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {sheetPart: _sheetXml(rows)},
      );

      expect(() => reader.read(bytes), throwsA(_readFailure('too many cells')));
    });

    test('a single cell far to the right trips the cell cap', () {
      const row = '<row r="1"><c r="XFD1"><v>1</v></c></row>';
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {sheetPart: _sheetXml(row)},
      );

      expect(
        () => const XlsxReader(maxCells: 100).read(bytes),
        throwsA(_readFailure('too many cells')),
      );
    });

    test('a sheet exactly at the cell cap is read', () {
      const reader = XlsxReader(maxCells: 8);
      const rows =
          '<row r="1"><c r="D1"><v>1</v></c></row>'
          '<row r="2"><c r="D2"><v>1</v></c></row>';
      final bytes = buildMoneyManagerXlsx(
        partOverrides: {sheetPart: _sheetXml(rows)},
      );

      expect(reader.read(bytes).rows, hasLength(2));
    });

    test('a negative shared string index', () {
      const row = '<row r="1"><c r="A1" t="s"><v>-1</v></c></row>';

      expect(() => _readSheet(row), throwsA(_readFailure('-1')));
    });
  });
}
