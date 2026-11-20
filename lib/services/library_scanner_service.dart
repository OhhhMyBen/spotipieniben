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

class LibraryScannerService {
  LibraryScannerService(this._audioQuery, this._storage);

  final OnAudioQuery _audioQuery;
  final StorageService _storage;

  static const Set<String> supportedExtensions = {
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.ogg',
  };

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
    final minMs = minDurationSeconds * 1000;

    for (final song in rawSongs) {
      final filePath = song.data;
      if (filePath.isEmpty) continue;

      final ext = p.extension(filePath).toLowerCase();
      if (!supportedExtensions.contains(ext)) continue;

      final durationMs = song.duration ?? 0;
      if (durationMs < minMs) continue;

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

    final folders = folderSet.toList()..sort();
    return LibraryScanResult(
      allTracks: tracks,
      discoveredFolders: folders,
    );
  }

  /// Lazily inspects ID3 embedded lyrics tags via `audiotags` for tracks that
  /// haven't been indexed yet so "ID3" badges appear in track lists.
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
