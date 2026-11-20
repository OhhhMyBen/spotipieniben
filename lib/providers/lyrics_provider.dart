import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lyric_line.dart';
import '../models/song_track.dart';
import 'app_providers.dart';
import 'library_provider.dart';
import 'playback_provider.dart';
import 'settings_provider.dart';

class LyricsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final lyricsRevisionProvider =
    NotifierProvider<LyricsRevisionNotifier, int>(LyricsRevisionNotifier.new);

class LyricsOffsetNotifier extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentTrackProvider.select((t) => t.value?.filePath));
    return 0;
  }

  void nudge(int deltaMs) {
    state = (state + deltaMs).clamp(-10000, 10000);
  }

  void reset() => state = 0;
}

final lyricsOffsetMsProvider =
    NotifierProvider<LyricsOffsetNotifier, int>(LyricsOffsetNotifier.new);

/// Null means follow automatic mode (Synced if timed, Static if plain).
/// `true` forces Synced view if synced lines exist; `false` forces Static ID3/text view.
class LyricsStaticModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(currentTrackProvider.select((t) => t.value?.filePath));
    return false;
  }

  void setForceStatic(bool value) => state = value;
}

final forceStaticLyricsProvider =
    NotifierProvider<LyricsStaticModeNotifier, bool>(
        LyricsStaticModeNotifier.new);

final currentTrackLyricsProvider = FutureProvider<TrackLyrics>((ref) async {
  final track = ref.watch(currentTrackProvider).value;
  if (track == null) return const TrackLyrics.empty();

  final preferExternalLrc =
      ref.watch(settingsProvider.select((s) => s.preferExternalLrc));
  ref.watch(lyricsRevisionProvider);

  final service = ref.watch(lyricsServiceProvider);
  return service.resolveLyrics(
    track,
    preferExternalLrc: preferExternalLrc,
  );
});

/// Computes the index of the currently active synced lyric line.
final activeLyricIndexProvider = Provider<int>((ref) {
  final lyrics = ref.watch(currentTrackLyricsProvider).value;
  if (lyrics == null || !lyrics.isSynced || lyrics.lines.isEmpty) return -1;

  final position =
      ref.watch(positionProvider).value ?? Duration.zero;
  final offsetMs = ref.watch(lyricsOffsetMsProvider);
  final effectiveMs = position.inMilliseconds + offsetMs;

  int activeIdx = -1;
  for (int i = 0; i < lyrics.lines.length; i++) {
    final ts = lyrics.lines[i].timestamp;
    if (ts == null) continue;
    if (ts.inMilliseconds <= effectiveMs) {
      activeIdx = i;
    } else {
      break;
    }
  }
  return activeIdx;
});

final lyricsActionsProvider = Provider<LyricsActions>((ref) {
  return LyricsActions(ref);
});

class LyricsActions {
  final Ref _ref;
  LyricsActions(this._ref);

  Future<bool> importLrcForTrack(SongTrack track) async {
    final service = _ref.read(lyricsServiceProvider);
    final imported = await service.importLrcForTrack(track);
    if (imported == null) return false;
    _ref.read(libraryProvider.notifier).markTrackHasLrc(track.filePath);
    _ref.read(lyricsRevisionProvider.notifier).bump();
    return true;
  }
}
