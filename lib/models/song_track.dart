import 'package:path/path.dart' as p;

enum LyricsSourceType {
  none,
  lrc,
  id3Synced,
  id3Unsynced,
}

class SongTrack {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int? albumId;
  final String filePath;
  final String? uri;
  final int durationMs;
  final int sizeBytes;
  final String fileExtension;
  final int dateAdded;
  final bool hasExternalLrc;
  final bool hasEmbeddedLyrics;
  final bool hasEmbeddedSyncedLyrics;

  const SongTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumId,
    required this.filePath,
    this.uri,
    required this.durationMs,
    required this.sizeBytes,
    required this.fileExtension,
    required this.dateAdded,
    this.hasExternalLrc = false,
    this.hasEmbeddedLyrics = false,
    this.hasEmbeddedSyncedLyrics = false,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  String get folderPath => p.dirname(filePath);

  String get folderName {
    final name = p.basename(folderPath);
    return name.isEmpty ? 'Root' : name;
  }

  String get formatBadge {
    final ext = fileExtension.toUpperCase().replaceFirst('.', '');
    if (ext == 'FLAC') return 'FLAC';
    if (ext == 'WAV') return 'WAV';
    if (ext == 'M4A') return 'M4A';
    if (ext == 'OGG') return 'OGG';
    return ext.isEmpty ? 'AUDIO' : ext;
  }

  String get audioSpecLabel {
    final ext = fileExtension.toUpperCase().replaceFirst('.', '');
    switch (ext) {
      case 'FLAC':
        return 'FLAC Lossless';
      case 'WAV':
        return 'WAV PCM';
      case 'AIFF':
      case 'AIF':
        return 'AIFF Lossless';
      case 'ALAC':
        return 'ALAC Lossless';
      case 'M4A':
      case 'M4B':
      case 'M4P':
        return 'AAC / ALAC';
      case 'AAC':
        return 'AAC Audio';
      case 'OPUS':
        return 'Opus Audio';
      case 'OGG':
      case 'OGA':
        return 'OGG Vorbis';
      case 'WEBM':
        return 'WebM Audio';
      case 'WMA':
        return 'WMA Audio';
      case 'AMR':
        return 'AMR Audio';
      case 'MKA':
        return 'Matroska Audio';
      case 'MP3':
        return 'MP3 Audio';
      default:
        return ext.isEmpty ? 'Local Audio' : '$ext Audio';
    }
  }

  /// Returns 'LRC', 'ID3', or null if neither is known to exist.
  String? get lyricsBadgeLabel {
    if (hasExternalLrc) return 'LRC';
    if (hasEmbeddedLyrics || hasEmbeddedSyncedLyrics) return 'ID3';
    return null;
  }

  bool get hasAnyLyrics =>
      hasExternalLrc || hasEmbeddedLyrics || hasEmbeddedSyncedLyrics;

  SongTrack copyWith({
    bool? hasExternalLrc,
    bool? hasEmbeddedLyrics,
    bool? hasEmbeddedSyncedLyrics,
  }) {
    return SongTrack(
      id: id,
      title: title,
      artist: artist,
      album: album,
      albumId: albumId,
      filePath: filePath,
      uri: uri,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      fileExtension: fileExtension,
      dateAdded: dateAdded,
      hasExternalLrc: hasExternalLrc ?? this.hasExternalLrc,
      hasEmbeddedLyrics: hasEmbeddedLyrics ?? this.hasEmbeddedLyrics,
      hasEmbeddedSyncedLyrics:
          hasEmbeddedSyncedLyrics ?? this.hasEmbeddedSyncedLyrics,
    );
  }
}

class LocalAlbum {
  final String name;
  final String artist;
  final int? albumId;
  final List<SongTrack> tracks;

  const LocalAlbum({
    required this.name,
    required this.artist,
    required this.albumId,
    required this.tracks,
  });

  int get trackCount => tracks.length;

  String get primaryFormat =>
      tracks.isNotEmpty ? tracks.first.formatBadge : 'AUDIO';
}

class LocalArtist {
  final String name;
  final List<SongTrack> tracks;
  final Set<String> albums;

  const LocalArtist({
    required this.name,
    required this.tracks,
    required this.albums,
  });
}

class LocalFolder {
  final String path;
  final String name;
  final List<SongTrack> tracks;

  const LocalFolder({
    required this.path,
    required this.name,
    required this.tracks,
  });
}

class LocalPlaylist {
  final String id;
  final String name;
  final List<String> trackPaths;
  final int createdAtMs;

  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.trackPaths,
    required this.createdAtMs,
  });

  LocalPlaylist copyWith({
    String? name,
    List<String>? trackPaths,
  }) {
    return LocalPlaylist(
      id: id,
      name: name ?? this.name,
      trackPaths: trackPaths ?? this.trackPaths,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trackPaths': trackPaths,
        'createdAtMs': createdAtMs,
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) {
    return LocalPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      trackPaths: List<String>.from(json['trackPaths'] as List? ?? const []),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
