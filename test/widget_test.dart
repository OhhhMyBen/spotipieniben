import 'package:flutter_test/flutter_test.dart';
import 'package:purplespotify/models/app_settings.dart';
import 'package:purplespotify/models/song_track.dart';
import 'package:purplespotify/services/lyrics_service.dart';
import 'package:purplespotify/services/storage_service.dart';
import 'package:purplespotify/utils/duration_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LRC Lyrics Parser', () {
    test('parses mm:ss.xx and mm:ss.xxx timestamps and sorts chronologically', () {
      const sampleLrc = '''
[ar:Stargazer]
[ti:Neon Voyage]
[offset:0]
[01:05.500]Second chorus line
[00:12.34]First verse line
[00:25.10][01:20.00]Repeated refrain
''';
      final parsed = LyricsService.parseLrcText(
        sampleLrc,
        sourceType: LyricsSourceType.lrc,
      );

      expect(parsed.isSynced, isTrue);
      expect(parsed.lines.length, 4);
      expect(parsed.lines[0].timestamp, const Duration(seconds: 12, milliseconds: 340));
      expect(parsed.lines[0].text, 'First verse line');
      expect(parsed.lines[1].timestamp, const Duration(seconds: 25, milliseconds: 100));
      expect(parsed.lines[1].text, 'Repeated refrain');
      expect(parsed.lines[2].timestamp, const Duration(minutes: 1, seconds: 5, milliseconds: 500));
      expect(parsed.lines[3].timestamp, const Duration(minutes: 1, seconds: 20));
      expect(parsed.lines[3].text, 'Repeated refrain');
    });

    test('applies positive and negative LRC offset tags', () {
      const lrcWithOffset = '''
[offset:500]
[00:10.00]Line with offset
''';
      final parsed = LyricsService.parseLrcText(
        lrcWithOffset,
        sourceType: LyricsSourceType.lrc,
      );
      expect(parsed.lines.single.timestamp, const Duration(seconds: 10, milliseconds: 500));
    });
  });

  group('Duration & Size Formatters', () {
    test('formats durations and remaining times accurately', () {
      expect(formatDuration(const Duration(seconds: 65)), '1:05');
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(
        formatRemaining(const Duration(seconds: 40), const Duration(minutes: 2)),
        '-1:20',
      );
      expect(formatFileSize(1024 * 1024 * 5), '5.0 MB');
    });
  });

  group('StorageService Persistence', () {
    test('persists settings, favorites, recently played, and playlists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      const updatedSettings = AppSettings(
        minDurationSeconds: 45,
        preferExternalLrc: false,
        lyricFontSize: LyricFontSize.large,
        gaplessPlayback: false,
      );
      await storage.saveSettings(updatedSettings);
      final loadedSettings = storage.loadSettings();
      expect(loadedSettings.minDurationSeconds, 45);
      expect(loadedSettings.preferExternalLrc, isFalse);
      expect(loadedSettings.lyricFontSize, LyricFontSize.large);
      expect(loadedSettings.gaplessPlayback, isFalse);

      await storage.saveFavorites({'/Music/a.mp3', '/Music/b.flac'});
      expect(storage.loadFavorites(), {'/Music/a.mp3', '/Music/b.flac'});

      await storage.saveRecentlyPlayed(['/Music/b.flac', '/Music/a.mp3']);
      expect(storage.loadRecentlyPlayed(), ['/Music/b.flac', '/Music/a.mp3']);

      const playlist = LocalPlaylist(
        id: 'pl1',
        name: 'Purple Synth',
        trackPaths: ['/Music/a.mp3'],
        createdAtMs: 123456,
      );
      await storage.savePlaylists([playlist]);
      final loadedPlaylists = storage.loadPlaylists();
      expect(loadedPlaylists.length, 1);
      expect(loadedPlaylists.first.name, 'Purple Synth');
      expect(loadedPlaylists.first.trackPaths, ['/Music/a.mp3']);
    });
  });
}
