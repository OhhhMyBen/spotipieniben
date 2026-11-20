import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/lyric_line.dart';
import '../models/song_track.dart';
import 'storage_service.dart';

class LyricsService {
  LyricsService(this._storage);

  final StorageService _storage;

  // Matches [mm:ss.xx], [mm:ss.xxx], or [mm:ss]
  static final RegExp _timestampRegex = RegExp(
    r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _offsetRegex = RegExp(
    r'^\[offset:\s*([+-]?\d+)\s*\]$',
    caseSensitive: false,
  );

  /// Finds the sibling .lrc file path for an audio file, if it exists on disk.
  static String expectedLrcPath(String audioFilePath) {
    final dir = p.dirname(audioFilePath);
    final stem = p.basenameWithoutExtension(audioFilePath);
    return p.join(dir, '$stem.lrc');
  }

  static bool hasSiblingLrcFile(String audioFilePath) {
    try {
      final lrcPath = expectedLrcPath(audioFilePath);
      if (File(lrcPath).existsSync()) return true;
      final upperLrcPath = p.join(
        p.dirname(audioFilePath),
        '${p.basenameWithoutExtension(audioFilePath)}.LRC',
      );
      return File(upperLrcPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Resolves lyrics for [track] in strict priority order:
  /// When [preferExternalLrc] is true:
  ///   1. Imported or sibling `.lrc` file
  ///   2. Embedded ID3 tags (synced if LRC-formatted, otherwise plain USLT)
  ///   3. Empty fallback state
  /// When [preferExternalLrc] is false, embedded ID3 is checked before `.lrc`.
  Future<TrackLyrics> resolveLyrics(
    SongTrack track, {
    bool preferExternalLrc = true,
  }) async {
    if (preferExternalLrc) {
      final lrc = await _loadExternalLrc(track.filePath);
      if (lrc != null && !lrc.isEmpty) return lrc;

      final id3 = await _loadEmbeddedId3(track.filePath);
      if (id3 != null && !id3.isEmpty) return id3;
    } else {
      final id3 = await _loadEmbeddedId3(track.filePath);
      if (id3 != null && !id3.isEmpty) return id3;

      final lrc = await _loadExternalLrc(track.filePath);
      if (lrc != null && !lrc.isEmpty) return lrc;
    }

    return const TrackLyrics.empty();
  }

  Future<TrackLyrics?> _loadExternalLrc(String audioFilePath) async {
    try {
      final customMap = _storage.loadCustomLrcMap();
      final candidates = <String>[
        if (customMap.containsKey(audioFilePath)) customMap[audioFilePath]!,
        expectedLrcPath(audioFilePath),
        p.join(
          p.dirname(audioFilePath),
          '${p.basenameWithoutExtension(audioFilePath)}.LRC',
        ),
      ];

      for (final path in candidates) {
        final file = File(path);
        if (await file.exists()) {
          final content = await _readFileWithFallbackEncoding(file);
          final parsed = parseLrcText(
            content,
            sourceType: LyricsSourceType.lrc,
            lrcFilePath: path,
          );
          if (!parsed.isEmpty) return parsed;
        }
      }
    } catch (_) {
      // Ignore inaccessible filesystem errors and fall back cleanly
    }
    return null;
  }

  Future<TrackLyrics?> _loadEmbeddedId3(String audioFilePath) async {
    try {
      final rawLyrics = await Isolate.run(() {
        final file = File(audioFilePath);
        if (!file.existsSync()) return null;
        final meta = readMetadata(file, getImage: false);
        return meta.lyrics?.trim();
      });
      if (rawLyrics == null || rawLyrics.isEmpty) return null;

      if (_timestampRegex.hasMatch(rawLyrics)) {
        return parseLrcText(
          rawLyrics,
          sourceType: LyricsSourceType.id3Synced,
        );
      }

      final plainLines = rawLyrics
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => LyricLine(text: line))
          .toList();

      if (plainLines.isEmpty) return null;

      return TrackLyrics(
        sourceType: LyricsSourceType.id3Unsynced,
        lines: plainLines,
        rawText: rawLyrics,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _readFileWithFallbackEncoding(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  /// Parses LRC-formatted text supporting `[mm:ss.xx]`, `[mm:ss.xxx]`,
  /// multiple timestamps per line, and `[offset:ms]`.
  static TrackLyrics parseLrcText(
    String raw, {
    required LyricsSourceType sourceType,
    String? lrcFilePath,
  }) {
    final lines = <LyricLine>[];
    int offsetMs = 0;

    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final offsetMatch = _offsetRegex.firstMatch(trimmed);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
        continue;
      }

      final matches = _timestampRegex.allMatches(trimmed).toList();
      if (matches.isEmpty) {
        // Skip metadata tags like [ar:Artist], [ti:Title], [al:Album]
        if (RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(trimmed)) {
          continue;
        }
        continue;
      }

      final lyricText = trimmed.replaceAll(_timestampRegex, '').trim();
      if (lyricText.isEmpty) continue;

      for (final m in matches) {
        final minutes = int.tryParse(m.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(m.group(2) ?? '0') ?? 0;
        final fracStr = m.group(3) ?? '0';
        int millis;
        if (fracStr.length == 1) {
          millis = (int.tryParse(fracStr) ?? 0) * 100;
        } else if (fracStr.length == 2) {
          millis = (int.tryParse(fracStr) ?? 0) * 10;
        } else {
          millis = int.tryParse(fracStr.substring(0, 3)) ?? 0;
        }

        final totalMs = (minutes * 60 * 1000) +
            (seconds * 1000) +
            millis +
            offsetMs;
        lines.add(
          LyricLine(
            timestamp: Duration(milliseconds: totalMs < 0 ? 0 : totalMs),
            text: lyricText,
          ),
        );
      }
    }

    lines.sort((a, b) =>
        (a.timestamp ?? Duration.zero).compareTo(b.timestamp ?? Duration.zero));

    return TrackLyrics(
      sourceType: sourceType,
      lines: lines,
      rawText: raw,
      lrcFilePath: lrcFilePath,
    );
  }

  /// Opens the native file picker to manually associate a `.lrc` file with a track.
  Future<TrackLyrics?> importLrcForTrack(SongTrack track) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Select .lrc lyrics file',
      type: FileType.any,
    );
    if (picked == null || picked.path == null) return null;

    final file = File(picked.path!);
    if (!await file.exists()) return null;

    final content = await _readFileWithFallbackEncoding(file);
    final parsed = parseLrcText(
      content,
      sourceType: LyricsSourceType.lrc,
      lrcFilePath: file.path,
    );

    if (!parsed.isEmpty) {
      await _storage.saveCustomLrcMapping(track.filePath, file.path);
      return parsed;
    }

    // Also allow plain-text import if the file had no timestamps
    final plainLines = content
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => LyricLine(text: e))
        .toList();
    if (plainLines.isEmpty) return null;

    await _storage.saveCustomLrcMapping(track.filePath, file.path);
    return TrackLyrics(
      sourceType: LyricsSourceType.lrc,
      lines: plainLines,
      rawText: content,
      lrcFilePath: file.path,
    );
  }
}
