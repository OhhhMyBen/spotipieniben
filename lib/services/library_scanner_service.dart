import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

import '../models/song_track.dart';
import 'lyrics_service.dart';
import 'storage_service.dart';

class LibraryScanResult {
  final List<SongTrack> allTracks;
  final List<String> discoveredFolders;

  const LibraryScanResult({
    required this.allTracks,
    required this.discoveredFolders,
  });
}

class _DiscoveredFileRecord {
  final String filePath;
  final String ext;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;
  final int dateAdded;

  const _DiscoveredFileRecord({
    required this.filePath,
    required this.ext,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    required this.dateAdded,
  });
}

class LibraryScannerService {
  LibraryScannerService(this._audioQuery, this._storage);

  final OnAudioQuery _audioQuery;
  final StorageService _storage;

  /// All audio formats accepted from Android MediaStore.Audio (ExoPlayer / just_audio).
  static const Set<String> supportedExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.m4p',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.oga',
    '.opus',
    '.webm',
    '.wma',
    '.aiff',
    '.aif',
    '.alac',
    '.amr',
    '.3gp',
    '.3gpp',
    '.mka',
    '.mp4',
    '.mp2',
    '.mpa',
    '.ape',
    '.wv',
    '.ac3',
  };

  /// Strictly audio-only formats used when supplementing MediaStore via direct
  /// filesystem traversal (excludes video containers like .mp4/.3gp/.webm).
  static const Set<String> filesystemAudioExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.m4p',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.oga',
    '.opus',
    '.wma',
    '.aiff',
    '.aif',
    '.alac',
    '.amr',
    '.mka',
    '.mp2',
    '.mpa',
    '.ape',
    '.wv',
    '.ac3',
  };

  /// Evaluates whether a candidate audio file should be included in the library.
  ///
  /// Tracks whose duration is unknown (`durationMs <= 0`, common in MediaStore
  /// for certain formats like `.opus`, `.flac`, or VBR `.mp3`) are NOT dropped
  /// by `minDurationSeconds` as long as the file has non-zero size.
  static bool shouldIncludeTrack({
    required String filePath,
    required int durationMs,
    required int sizeBytes,
    required int minDurationSeconds,
    bool fromMediaStore = true,
  }) {
    if (filePath.isEmpty) return false;

    final ext = p.extension(filePath).toLowerCase();
    if (fromMediaStore) {
      if (ext.isNotEmpty && !supportedExtensions.contains(ext)) return false;
    } else {
      if (!filesystemAudioExtensions.contains(ext)) return false;
    }

    // Skip empty/ghost entries with neither size nor duration.
    if (sizeBytes <= 0 && durationMs <= 0) return false;

    final minMs = minDurationSeconds * 1000;
    if (minMs > 0 && durationMs > 0 && durationMs < minMs) {
      return false;
    }

    return true;
  }

  static int _syntheticTrackId(String filePath) {
    // Deterministic negative ID so it never collides with positive MediaStore IDs.
    var hash = 0x811c9dc5;
    for (final unit in filePath.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return -((hash % 0x7ffffffe) + 1);
  }

  Future<LibraryScanResult> scanDeviceLibrary({
    required int minDurationSeconds,
  }) async {
    if (kIsWeb) {
      return const LibraryScanResult(allTracks: [], discoveredFolders: []);
    }

    final rawSongs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final customLrcMap = _storage.loadCustomLrcMap();
    final cachedId3Flags = _storage.loadId3LyricsFlags();

    final tracks = <SongTrack>[];
    final folderSet = <String>{};
    final seenPaths = <String>{};

    for (final song in rawSongs) {
      final filePath = song.data;
      final durationMs = song.duration ?? 0;

      if (!shouldIncludeTrack(
        filePath: filePath,
        durationMs: durationMs,
        sizeBytes: song.size,
        minDurationSeconds: minDurationSeconds,
        fromMediaStore: true,
      )) {
        continue;
      }

      final normalizedPath = filePath.toLowerCase();
      if (!seenPaths.add(normalizedPath)) continue;

      final ext = p.extension(filePath).toLowerCase();
      final folderPath = p.dirname(filePath);
      folderSet.add(folderPath);

      final hasLrc = customLrcMap.containsKey(filePath) ||
          LyricsService.hasSiblingLrcFile(filePath);

      final id3Flag = cachedId3Flags[filePath];
      final hasEmbedded = id3Flag == 'plain' || id3Flag == 'synced';
      final hasEmbeddedSynced = id3Flag == 'synced';

      final cleanTitle = song.title.trim().isNotEmpty
          ? song.title.trim()
          : p.basenameWithoutExtension(filePath);
      final cleanArtist = (song.artist == null ||
              song.artist!.trim().isEmpty ||
              song.artist == '<unknown>')
          ? 'Unknown Artist'
          : song.artist!.trim();
      final cleanAlbum =
          (song.album == null || song.album!.trim().isEmpty)
              ? 'Unknown Album'
              : song.album!.trim();

      tracks.add(
        SongTrack(
          id: song.id,
          title: cleanTitle,
          artist: cleanArtist,
          album: cleanAlbum,
          albumId: song.albumId,
          filePath: filePath,
          uri: song.uri,
          durationMs: durationMs,
          sizeBytes: song.size,
          fileExtension: ext,
          dateAdded: song.dateAdded ?? 0,
          hasExternalLrc: hasLrc,
          hasEmbeddedLyrics: hasEmbedded,
          hasEmbeddedSyncedLyrics: hasEmbeddedSynced,
        ),
      );
    }

    // Supplement MediaStore with a direct filesystem scan of discovered music
    // folders and standard Android audio directories to catch unindexed files
    // (e.g. newly downloaded tracks, .opus/.aac/.flac files skipped by MediaStore).
    if (Platform.isAndroid) {
      final extraFiles = await _scanFallbackDirectories(
        discoveredFolders: folderSet.toList(),
        seenPaths: seenPaths,
        minDurationSeconds: minDurationSeconds,
      );

      for (final file in extraFiles) {
        final folderPath = p.dirname(file.filePath);
        folderSet.add(folderPath);

        final hasLrc = customLrcMap.containsKey(file.filePath) ||
            LyricsService.hasSiblingLrcFile(file.filePath);

        final id3Flag = cachedId3Flags[file.filePath];
        final hasEmbedded = id3Flag == 'plain' || id3Flag == 'synced';
        final hasEmbeddedSynced = id3Flag == 'synced';

        tracks.add(
          SongTrack(
            id: _syntheticTrackId(file.filePath),
            title: file.title,
            artist: file.artist,
            album: file.album,
            albumId: null,
            filePath: file.filePath,
            uri: null,
            durationMs: file.durationMs,
            sizeBytes: file.sizeBytes,
            fileExtension: file.ext,
            dateAdded: file.dateAdded,
            hasExternalLrc: hasLrc,
            hasEmbeddedLyrics: hasEmbedded,
            hasEmbeddedSyncedLyrics: hasEmbeddedSynced,
          ),
        );
      }
    }

    tracks.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    final folders = folderSet.toList()..sort();
    return LibraryScanResult(
      allTracks: tracks,
      discoveredFolders: folders,
    );
  }

  Future<List<_DiscoveredFileRecord>> _scanFallbackDirectories({
    required List<String> discoveredFolders,
    required Set<String> seenPaths,
    required int minDurationSeconds,
  }) async {
    final seenCopy = Set<String>.from(seenPaths);
    final foldersCopy = List<String>.from(discoveredFolders);

    try {
      return await Isolate.run(() {
        final candidateRoots = <String>{
          ...foldersCopy,
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/storage/emulated/0/Audio',
          '/storage/emulated/0/Songs',
          '/storage/emulated/0/Podcasts',
          '/storage/emulated/0/Audiobooks',
          '/storage/emulated/0/Recordings',
          '/storage/emulated/0/Snaptube',
          '/storage/emulated/0/Telegram',
        };

        // Also check removable SD card volumes under /storage/
        try {
          final storageRoot = Directory('/storage');
          if (storageRoot.existsSync()) {
            for (final entry in storageRoot.listSync(followLinks: false)) {
              if (entry is! Directory) continue;
              final name = p.basename(entry.path);
              if (name == 'emulated' || name == 'self') continue;
              candidateRoots.add(p.join(entry.path, 'Music'));
              candidateRoots.add(p.join(entry.path, 'Download'));
              candidateRoots.add(p.join(entry.path, 'Downloads'));
              candidateRoots.add(p.join(entry.path, 'Audio'));
            }
          }
        } catch (_) {
          // Ignore if /storage cannot be listed
        }

        final visitedDirs = <String>{};
        final found = <_DiscoveredFileRecord>[];

        void walkDirectory(Directory dir) {
          final dirKey = dir.path.toLowerCase();
          if (!visitedDirs.add(dirKey)) return;

          List<FileSystemEntity> entries;
          try {
            if (!dir.existsSync()) return;
            entries = dir.listSync(followLinks: false);
          } catch (_) {
            return;
          }

          for (final entity in entries) {
            if (entity is Directory) {
              final name = p.basename(entity.path);
              if (name.startsWith('.')) continue;
              final lowerPath = entity.path.toLowerCase();
              if (lowerPath.contains('/android/data') ||
                  lowerPath.contains('/android/obb')) {
                continue;
              }
              walkDirectory(entity);
            } else if (entity is File) {
              final filePath = entity.path;
              final normalized = filePath.toLowerCase();
              if (seenCopy.contains(normalized)) continue;

              final ext = p.extension(filePath).toLowerCase();
              if (!filesystemAudioExtensions.contains(ext)) continue;

              FileStat stat;
              try {
                stat = entity.statSync();
              } catch (_) {
                continue;
              }
              if (stat.size <= 0) continue;

              String title = p.basenameWithoutExtension(filePath);
              String artist = 'Unknown Artist';
              String album = 'Unknown Album';
              int durationMs = 0;

              try {
                final meta = readMetadata(entity, getImage: false);
                if (meta.title != null && meta.title!.trim().isNotEmpty) {
                  title = meta.title!.trim();
                }
                if (meta.artist != null &&
                    meta.artist!.trim().isNotEmpty &&
                    meta.artist != '<unknown>') {
                  artist = meta.artist!.trim();
                }
                if (meta.album != null && meta.album!.trim().isNotEmpty) {
                  album = meta.album!.trim();
                }
                durationMs = meta.duration?.inMilliseconds ?? 0;
              } catch (_) {
                // Fall back to filename metadata when tag parsing is unsupported
              }

              if (!shouldIncludeTrack(
                filePath: filePath,
                durationMs: durationMs,
                sizeBytes: stat.size,
                minDurationSeconds: minDurationSeconds,
                fromMediaStore: false,
              )) {
                continue;
              }

              seenCopy.add(normalized);
              found.add(
                _DiscoveredFileRecord(
                  filePath: filePath,
                  ext: ext,
                  title: title,
                  artist: artist,
                  album: album,
                  durationMs: durationMs,
                  sizeBytes: stat.size,
                  dateAdded: stat.modified.millisecondsSinceEpoch ~/ 1000,
                ),
              );
            }
          }
        }

        for (final rootPath in candidateRoots) {
          walkDirectory(Directory(rootPath));
        }

        return found;
      });
    } catch (_) {
      return const [];
    }
  }

  /// Lazily inspects ID3 embedded lyrics tags via `audio_metadata_reader` for
  /// tracks that haven't been indexed yet so "ID3" badges appear in track lists.
  Future<Map<String, String>> indexId3LyricsFlags(
    List<SongTrack> tracks, {
    void Function(Map<String, String> updated)? onBatchReady,
  }) async {
    final flags = Map<String, String>.from(_storage.loadId3LyricsFlags());
    bool changed = false;
    int processedSinceEmit = 0;

    for (final track in tracks) {
      if (flags.containsKey(track.filePath)) continue;
      if (!File(track.filePath).existsSync()) continue;

      try {
        final raw = await Isolate.run(() {
          final meta = readMetadata(File(track.filePath), getImage: false);
          return meta.lyrics?.trim() ?? '';
        });
        if (raw.isEmpty) {
          flags[track.filePath] = 'none';
        } else if (RegExp(r'\[\d{1,3}:\d{2}').hasMatch(raw)) {
          flags[track.filePath] = 'synced';
        } else {
          flags[track.filePath] = 'plain';
        }
        changed = true;
        processedSinceEmit++;

        if (processedSinceEmit >= 12) {
          processedSinceEmit = 0;
          await _storage.saveId3LyricsFlags(flags);
          onBatchReady?.call(Map<String, String>.from(flags));
        }
      } catch (_) {
        flags[track.filePath] = 'none';
      }
    }

    if (changed) {
      await _storage.saveId3LyricsFlags(flags);
      onBatchReady?.call(Map<String, String>.from(flags));
    }

    return flags;
  }
}
