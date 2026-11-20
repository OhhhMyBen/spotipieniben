import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song_track.dart';
import '../theme/app_theme.dart';
import 'app_providers.dart';
import 'library_provider.dart';

final currentTrackProvider = StreamProvider<SongTrack?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.currentTrackStream;
});

final queueTracksProvider = StreamProvider<List<SongTrack>>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.queueTracksStream;
});

final sourceLabelProvider = StreamProvider<String>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.sourceLabelStream;
});

final isPlayingProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playingStream;
});

final positionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.durationStream;
});

final shuffleEnabledProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.shuffleEnabledStream;
});

final loopModeProvider = StreamProvider<LoopMode>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.loopModeStream;
});

final playbackSpeedProvider = StreamProvider<double>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.speedStream;
});

class SleepTimerNotifier extends Notifier<Duration?> {
  Timer? _timer;

  @override
  Duration? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void setTimer(Duration? duration) {
    _timer?.cancel();
    if (duration == null || duration <= Duration.zero) {
      state = null;
      return;
    }
    state = duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final current = state;
      if (current == null || current.inSeconds <= 1) {
        t.cancel();
        state = null;
        ref.read(audioHandlerProvider).pause();
      } else {
        state = Duration(seconds: current.inSeconds - 1);
      }
    });
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, Duration?>(SleepTimerNotifier.new);

final currentTrackDominantColorProvider = FutureProvider<Color>((ref) async {
  final track = ref.watch(currentTrackProvider).value;
  if (track == null) return AppColors.surfaceDeepPlum;
  final artworkService = ref.watch(artworkServiceProvider);
  return artworkService.getDominantColor(track);
});

/// Helper controller for starting playback and recording recently played history.
final playbackControllerProvider = Provider<PlaybackController>((ref) {
  return PlaybackController(ref);
});

class PlaybackController {
  final Ref _ref;
  String? _lastRecordedPath;

  PlaybackController(this._ref) {
    _ref.listen<AsyncValue<SongTrack?>>(currentTrackProvider, (_, next) {
      final track = next.value;
      if (track != null && track.filePath != _lastRecordedPath) {
        _lastRecordedPath = track.filePath;
        _ref.read(libraryProvider.notifier).recordPlayed(track);
      }
    });
  }

  Future<void> playTracks(
    List<SongTrack> tracks, {
    int initialIndex = 0,
    String sourceLabel = 'Local Storage',
  }) async {
    if (tracks.isEmpty) return;
    final handler = _ref.read(audioHandlerProvider);
    await handler.setQueueAndPlay(
      tracks,
      initialIndex: initialIndex,
      sourceLabel: sourceLabel,
    );
  }

  Future<void> playSingle(
    SongTrack track, {
    List<SongTrack>? contextList,
    String sourceLabel = 'Local Storage',
  }) async {
    final queue = contextList != null && contextList.isNotEmpty
        ? contextList
        : [track];
    final idx = queue.indexWhere((t) => t.filePath == track.filePath);
    await playTracks(
      queue,
      initialIndex: idx < 0 ? 0 : idx,
      sourceLabel: sourceLabel,
    );
  }
}
