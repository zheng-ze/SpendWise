import 'dart:io';

const _sourcePrefix = 'SF:';
const _lineRecordPrefix = 'DA:';
const _recordSeparator = ',';
const _libraryRoot = 'lib/';
const _percentScale = 100;
const _percentDigits = 2;

const _generatedSuffix = '.g.dart';
const _excludedUiDirectories = ['lib/ui/theme/', 'lib/ui/money/'];
const _excludedUiSuffixes = [
  '_screen.dart',
  '_sheet.dart',
  '_view.dart',
  '_card.dart',
  '_row.dart',
  '_rows.dart',
  '_section.dart',
  '_sections.dart',
  '_picker.dart',
  '_chart.dart',
  '_bar.dart',
];

bool _isExcluded(String path) {
  if (path.endsWith(_generatedSuffix)) return true;
  if (!path.startsWith('${_libraryRoot}ui/')) return false;
  if (_excludedUiDirectories.any(path.startsWith)) return true;
  return _excludedUiSuffixes.any(path.endsWith);
}

String _percent(int hit, int found) {
  if (found == 0) return '0';
  return (hit * _percentScale / found).toStringAsFixed(_percentDigits);
}

Map<String, Map<int, int>> _readHits(File report) {
  final hitsBySource = <String, Map<int, int>>{};
  late Map<int, int> current;
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith(_sourcePrefix)) {
      final path = line.substring(_sourcePrefix.length);
      current = hitsBySource.putIfAbsent(path, () => {});
      continue;
    }
    if (!line.startsWith(_lineRecordPrefix)) continue;
    final parts = line
        .substring(_lineRecordPrefix.length)
        .split(_recordSeparator);
    final number = int.parse(parts[0]);
    final hits = int.parse(parts[1]);
    final previous = current[number] ?? 0;
    current[number] = hits > previous ? hits : previous;
  }
  return hitsBySource;
}

void main(List<String> arguments) {
  final report = File(
    arguments.isEmpty ? 'coverage/lcov.info' : arguments.first,
  );
  if (!report.existsSync()) {
    stderr.writeln('Coverage file not found: ${report.path}');
    exitCode = 1;
    return;
  }

  var allFound = 0;
  var allHit = 0;
  var keptFound = 0;
  var keptHit = 0;
  for (final entry in _readHits(report).entries) {
    final found = entry.value.length;
    final hit = entry.value.values.where((hits) => hits > 0).length;
    allFound += found;
    allHit += hit;
    if (_isExcluded(entry.key)) continue;
    keptFound += found;
    keptHit += hit;
  }

  stdout
    ..writeln(
      '## App test coverage (generated code and UI declarations excluded)',
    )
    ..writeln()
    ..writeln('| Metric | Result |')
    ..writeln('| --- | ---: |')
    ..writeln('| Lines hit | $keptHit |')
    ..writeln('| Lines found | $keptFound |')
    ..writeln('| Line coverage | ${_percent(keptHit, keptFound)}% |')
    ..writeln(
      '| Line coverage, nothing excluded | ${_percent(allHit, allFound)}% |',
    );
}
