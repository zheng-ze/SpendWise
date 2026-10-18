import 'dart:convert';
import 'dart:io';

const _framesPath = '../docs/design/ui-revamp/frames.json';

class FrameEntry {
  const FrameEntry({required this.id, required this.area});

  final String id;

  final String area;
}

FrameEntry _parseRow(Object? row) {
  if (row case {'id': final String id, 'area': final String area}) {
    return FrameEntry(id: id, area: area);
  }
  throw FormatException('Bad frame row: $row');
}

class FrameManifest {
  FrameManifest(List<FrameEntry> frames) : frames = List.unmodifiable(frames);

  factory FrameManifest.load({String path = _framesPath}) {
    final decoded = json.decode(File(path).readAsStringSync());
    if (decoded is! List) {
      throw FormatException('Frame manifest at $path is not a list.');
    }
    return FrameManifest([for (final row in decoded) _parseRow(row)]);
  }

  final List<FrameEntry> frames;

  Set<String> get ids => {for (final frame in frames) frame.id};

  Set<String> idsInArea(String area) => {
    for (final frame in frames)
      if (frame.area == area) frame.id,
  };

  Set<String> idsMatching(Pattern pattern) => {
    for (final frame in frames)
      if (frame.id.startsWith(pattern)) frame.id,
  };
}
