import 'song_track.dart';

class LyricLine {
  final Duration? timestamp;
  final String text;

  const LyricLine({
    this.timestamp,
    required this.text,
  });

  bool get isSynced => timestamp != null;
}

class TrackLyrics {
  final LyricsSourceType sourceType;
  final List<LyricLine> lines;
  final String rawText;
  final String? lrcFilePath;

  const TrackLyrics({
    required this.sourceType,
    required this.lines,
    required this.rawText,
    this.lrcFilePath,
  });

  const TrackLyrics.empty()
      : sourceType = LyricsSourceType.none,
        lines = const [],
        rawText = '',
        lrcFilePath = null;

  bool get isEmpty => lines.isEmpty;

  bool get isSynced =>
      sourceType == LyricsSourceType.lrc ||
      sourceType == LyricsSourceType.id3Synced;

  String get badgeLabel {
    switch (sourceType) {
      case LyricsSourceType.lrc:
        return 'LRC';
      case LyricsSourceType.id3Synced:
      case LyricsSourceType.id3Unsynced:
        return 'ID3';
      case LyricsSourceType.none:
        return '';
    }
  }

  String get modeLabel {
    switch (sourceType) {
      case LyricsSourceType.lrc:
      case LyricsSourceType.id3Synced:
        return 'Synced LRC';
      case LyricsSourceType.id3Unsynced:
        return 'Static ID3';
      case LyricsSourceType.none:
        return 'No Lyrics';
    }
  }
}
