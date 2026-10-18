import 'dart:convert';
import 'dart:io';

const _framesPath = '../docs/design/ui-revamp/frames.json';

class FrameEntry {
  const FrameEntry({required this.id, required this.area});

  final String id;

  final String area;
}

class FrameManifest {
  FrameManifest(List<FrameEntry> frames) : frames = List.unmodifiable(frames);

  factory FrameManifest.load({String path = _framesPath}) {
    final decoded = json.decode(File(path).readAsStringSync());
    if (decoded is! List) {
      throw FormatException('Frame manifest at $path is not a list.');
    }
    final frames = [
      for (final row in decoded)
        if (row case {'id': final String id, 'area': final String area})
          FrameEntry(id: id, area: area),
    ];
    return FrameManifest(frames);
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
