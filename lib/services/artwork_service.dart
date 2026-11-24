import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/song_track.dart';
import '../theme/app_theme.dart';

class ArtworkService {
  ArtworkService(this._audioQuery);

  static const int maxMemoryEntries = 60;
  static const int maxMemoryBytes = 24 * 1024 * 1024; // 24 MB cap
  static const int maxColorEntries = 120;

  final OnAudioQuery _audioQuery;
  final LinkedHashMap<int, Uint8List?> _memoryCache = LinkedHashMap();
  final LinkedHashMap<int, Color> _dominantColorCache = LinkedHashMap();
  final Map<int, Future<Uint8List?>> _inFlight = {};
  int _memoryCacheBytes = 0;

  void _putMemoryCache(int trackId, Uint8List? bytes) {
    final existing = _memoryCache.remove(trackId);
    if (existing != null) {
      _memoryCacheBytes -= existing.length;
    }

    // Do not cache single images larger than 4 MB in RAM.
    if (bytes != null && bytes.length > 4 * 1024 * 1024) {
      return;
    }

    _memoryCache[trackId] = bytes;
    if (bytes != null) {
      _memoryCacheBytes += bytes.length;
    }

    while (_memoryCache.length > maxMemoryEntries ||
        _memoryCacheBytes > maxMemoryBytes) {
      if (_memoryCache.isEmpty) break;
      final oldestKey = _memoryCache.keys.first;
      final removed = _memoryCache.remove(oldestKey);
      if (removed != null) {
        _memoryCacheBytes -= removed.length;
      }
    }
  }

  void _putColorCache(int trackId, Color color) {
    _dominantColorCache.remove(trackId);
    _dominantColorCache[trackId] = color;
    while (_dominantColorCache.length > maxColorEntries) {
      _dominantColorCache.remove(_dominantColorCache.keys.first);
    }
  }

  Future<Uint8List?> getArtworkBytes(SongTrack track, {int size = 500}) {
    if (_memoryCache.containsKey(track.id)) {
      // Refresh LRU recency
      final cached = _memoryCache.remove(track.id);
      _memoryCache[track.id] = cached;
      return Future.value(cached);
    }
    return _inFlight.putIfAbsent(track.id, () async {
      try {
        Uint8List? bytes;
        // Try high-res embedded picture using pure-Dart audio_metadata_reader first
        try {
          bytes = await Isolate.run(() {
            final file = File(track.filePath);
            if (!file.existsSync()) return null;
            final meta = readMetadata(file, getImage: true);
            if (meta.pictures.isNotEmpty) {
              return meta.pictures.first.bytes;
            }
            return null;
          });
        } catch (_) {
          // Fall back to MediaStore artwork query
        }

        // Fall back to MediaStore artwork query (only for positive MediaStore IDs)
        if ((bytes == null || bytes.isEmpty) && track.id > 0) {
          bytes = await _audioQuery.queryArtwork(
            track.id,
            ArtworkType.AUDIO,
            format: ArtworkFormat.JPEG,
            size: size,
            quality: 90,
          );
        }

        if ((bytes == null || bytes.isEmpty) && track.albumId != null) {
          bytes = await _audioQuery.queryArtwork(
            track.albumId!,
            ArtworkType.ALBUM,
            format: ArtworkFormat.JPEG,
            size: size,
            quality: 90,
          );
        }

        final result = (bytes != null && bytes.isNotEmpty) ? bytes : null;
        _putMemoryCache(track.id, result);
        return result;
      } catch (_) {
        _putMemoryCache(track.id, null);
        return null;
      } finally {
        _inFlight.remove(track.id);
      }
    });
  }

  /// Writes artwork to app cache directory so Android MediaNotification can
  /// display album cover art via `file://` URI.
  Future<Uri?> getArtworkFileUri(SongTrack track) async {
    try {
      final dir = await getTemporaryDirectory();
      final artDir = Directory(p.join(dir.path, 'aura_artwork_cache'));
      if (!await artDir.exists()) {
        await artDir.create(recursive: true);
      }
      final file = File(p.join(artDir.path, 'art_${track.id}.jpg'));
      if (await file.exists()) {
        return Uri.file(file.path);
      }

      final bytes = await getArtworkBytes(track, size: 512);
      if (bytes == null || bytes.isEmpty) return null;

      await file.writeAsBytes(bytes, flush: true);
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  /// Extracts a vibrant dominant accent color from the album artwork bytes
  /// for the Now Playing gradient backdrop.
  Future<Color> getDominantColor(SongTrack track) async {
    if (_dominantColorCache.containsKey(track.id)) {
      return _dominantColorCache[track.id]!;
    }

    final bytes = await getArtworkBytes(track, size: 200);
    if (bytes == null || bytes.isEmpty) {
      return AppColors.surfaceDeepPlum;
    }

    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      final image = await completer.future;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();

      if (byteData == null) return AppColors.surfaceDeepPlum;

      final data = byteData.buffer.asUint8List();
      int rSum = 0;
      int gSum = 0;
      int bSum = 0;
      int count = 0;

      // Sample every 16th pixel for fast, low-overhead dominant hue calculation
      for (int i = 0; i + 3 < data.length; i += 64) {
        final r = data[i];
        final g = data[i + 1];
        final b = data[i + 2];
        final a = data[i + 3];
        if (a < 128) continue;
        // Skip near-black or near-white pixels
        final maxChannel = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final minChannel = r < g ? (r < b ? r : b) : (g < b ? g : b);
        if (maxChannel < 24 || minChannel > 235) continue;

        rSum += r;
        gSum += g;
        bSum += b;
        count++;
      }

      if (count == 0) return AppColors.surfaceDeepPlum;

      final avgColor = Color.fromARGB(
        255,
        (rSum ~/ count).clamp(0, 255),
        (gSum ~/ count).clamp(0, 255),
        (bSum ~/ count).clamp(0, 255),
      );
      // Blend slightly toward Purple Mode deep plum so the UI remains cohesive
      final blended =
          Color.lerp(avgColor, AppColors.lyricsFullBackdrop, 0.42) ??
              AppColors.surfaceDeepPlum;
      _putColorCache(track.id, blended);
      return blended;
    } catch (_) {
      return AppColors.surfaceDeepPlum;
    }
  }

  Future<int> getCacheSizeBytes() async {
    try {
      final dir = await getTemporaryDirectory();
      final artDir = Directory(p.join(dir.path, 'aura_artwork_cache'));
      if (!await artDir.exists()) return 0;
      int total = 0;
      await for (final entity in artDir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    _memoryCacheBytes = 0;
    _dominantColorCache.clear();
    try {
      final dir = await getTemporaryDirectory();
      final artDir = Directory(p.join(dir.path, 'aura_artwork_cache'));
      if (await artDir.exists()) {
        await artDir.delete(recursive: true);
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}
