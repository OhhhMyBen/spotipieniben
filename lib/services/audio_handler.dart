import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../models/song_track.dart';
import 'artwork_service.dart';

class AuraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  AuraAudioHandler(this._artworkService) {
    _init();
  }

  final ArtworkService _artworkService;
  final AudioPlayer _player = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: true,
  );

  final BehaviorSubject<List<SongTrack>> _tracksSubject =
      BehaviorSubject.seeded(const []);
  final BehaviorSubject<SongTrack?> _currentTrackSubject =
      BehaviorSubject.seeded(null);
  final BehaviorSubject<String> _sourceLabelSubject =
      BehaviorSubject.seeded('Local Storage');

  bool _pauseOnHeadsetDisconnect = true;
  bool _gaplessPlayback = true;
  bool _resumeAfterInterruption = false;

  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  StreamSubscription<int?>? _currentIndexSub;
  StreamSubscription<SequenceState?>? _sequenceSub;
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  AudioPlayer get player => _player;

  List<SongTrack> get currentQueue => _tracksSubject.value;
  SongTrack? get currentTrack => _currentTrackSubject.value;
  String get currentSourceLabel => _sourceLabelSubject.value;

  Stream<List<SongTrack>> get queueTracksStream => _tracksSubject.stream;
  Stream<SongTrack?> get currentTrackStream => _currentTrackSubject.stream;
  Stream<String> get sourceLabelStream => _sourceLabelSubject.stream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<bool> get shuffleEnabledStream => _player.shuffleModeEnabledStream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<double> get speedStream => _player.speedStream;

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _noisySub = session.becomingNoisyEventStream.listen((_) {
      if (_pauseOnHeadsetDisconnect && _player.playing) {
        pause();
      }
    });

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.35);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_player.playing) {
              _resumeAfterInterruption = true;
              pause();
            }
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            if (_resumeAfterInterruption) {
              _resumeAfterInterruption = false;
              play();
            }
            break;
          case AudioInterruptionType.unknown:
            _resumeAfterInterruption = false;
            break;
        }
      }
    });

    _playbackEventSub = _player.playbackEventStream.listen(_broadcastState);
    _currentIndexSub = _player.currentIndexStream.listen(_onIndexChanged);
    _sequenceSub = _player.sequenceStateStream.listen((seq) {
      if (seq.currentIndex != null) {
        _onIndexChanged(seq.currentIndex);
      }
    });
  }

  void updateAudioPreferences({
    required bool gaplessPlayback,
    required bool pauseOnHeadsetDisconnect,
  }) {
    _gaplessPlayback = gaplessPlayback;
    _pauseOnHeadsetDisconnect = pauseOnHeadsetDisconnect;
  }

  Future<void> setQueueAndPlay(
    List<SongTrack> tracks, {
    int initialIndex = 0,
    String sourceLabel = 'Local Storage',
  }) async {
    if (tracks.isEmpty) return;

    final safeIndex = initialIndex.clamp(0, tracks.length - 1);
    _sourceLabelSubject.add(sourceLabel);
    _tracksSubject.add(List<SongTrack>.from(tracks));
    queueTitle.add(sourceLabel);

    final mediaItems = tracks.map(_toMediaItem).toList();
    queue.add(mediaItems);

    final sources = tracks
        .map((t) => AudioSource.file(t.filePath, tag: _toMediaItem(t)))
        .toList();

    final session = await AudioSession.instance;
    await session.setActive(true);

    await _player.setAudioSources(
      sources,
      initialIndex: safeIndex,
      initialPosition: Duration.zero,
      preload: _gaplessPlayback,
    );

    await _updateCurrentMediaItem(tracks[safeIndex]);
    await _player.play();
  }

  Future<void> playNext(SongTrack track) async {
    final list = List<SongTrack>.from(_tracksSubject.value);
    if (list.isEmpty) {
      await setQueueAndPlay([track], sourceLabel: 'Queue');
      return;
    }

    final currentIdx = _player.currentIndex ?? 0;
    final insertIdx = (currentIdx + 1).clamp(0, list.length);
    list.insert(insertIdx, track);

    final item = _toMediaItem(track);
    _tracksSubject.add(list);
    queue.add(list.map(_toMediaItem).toList());
    await _player.insertAudioSource(
      insertIdx,
      AudioSource.file(track.filePath, tag: item),
    );
  }

  Future<void> addToQueue(SongTrack track) async {
    final list = List<SongTrack>.from(_tracksSubject.value);
    if (list.isEmpty) {
      await setQueueAndPlay([track], sourceLabel: 'Queue');
      return;
    }

    list.add(track);
    final item = _toMediaItem(track);
    _tracksSubject.add(list);
    queue.add(list.map(_toMediaItem).toList());
    await _player.addAudioSource(
      AudioSource.file(track.filePath, tag: item),
    );
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final list = List<SongTrack>.from(_tracksSubject.value);
    if (oldIndex < 0 || oldIndex >= list.length) return;

    final targetIndex = newIndex.clamp(0, list.length - 1);
    if (oldIndex == targetIndex) return;

    final moved = list.removeAt(oldIndex);
    list.insert(targetIndex, moved);
    _tracksSubject.add(list);
    queue.add(list.map(_toMediaItem).toList());
    await _player.moveAudioSource(oldIndex, targetIndex);
  }

  Future<void> removeFromQueue(int index) async {
    final list = List<SongTrack>.from(_tracksSubject.value);
    if (index < 0 || index >= list.length) return;
    if (list.length == 1) {
      await stop();
      _tracksSubject.add(const []);
      _currentTrackSubject.add(null);
      queue.add(const []);
      mediaItem.add(null);
      return;
    }

    list.removeAt(index);
    _tracksSubject.add(list);
    queue.add(list.map(_toMediaItem).toList());
    await _player.removeAudioSourceAt(index);
  }

  MediaItem _toMediaItem(SongTrack track) {
    return MediaItem(
      id: track.filePath,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      extras: {'trackId': track.id},
    );
  }

  Future<void> _onIndexChanged(int? index) async {
    final tracks = _tracksSubject.value;
    if (index == null || index < 0 || index >= tracks.length) return;
    final track = tracks[index];
    if (_currentTrackSubject.value?.filePath == track.filePath &&
        mediaItem.value?.id == track.filePath) {
      return;
    }
    await _updateCurrentMediaItem(track);
  }

  Future<void> _updateCurrentMediaItem(SongTrack track) async {
    _currentTrackSubject.add(track);
    final baseItem = _toMediaItem(track);
    mediaItem.add(baseItem);

    // Resolve artwork file URI asynchronously for notification / lock-screen
    final artUri = await _artworkService.getArtworkFileUri(track);
    if (artUri != null && _currentTrackSubject.value?.filePath == track.filePath) {
      mediaItem.add(baseItem.copyWith(artUri: artUri));
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = event.currentIndex ?? _player.currentIndex;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex,
        repeatMode: _mapLoopModeToService(_player.loopMode),
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  AudioServiceRepeatMode _mapLoopModeToService(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
    }
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    await session.setActive(true);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    final list = _tracksSubject.value;
    if (index < 0 || index >= list.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) {
      await play();
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_tracksSubject.value.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_tracksSubject.value.isNotEmpty) {
      await _player.seek(Duration.zero, index: _tracksSubject.value.length - 1);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    if (enabled) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> toggleShuffle() async {
    final next = !_player.shuffleModeEnabled;
    await setShuffleMode(
      next ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
    }
  }

  Future<void> cycleRepeatMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        await setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case LoopMode.all:
        await setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case LoopMode.one:
        await setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
  }

  Future<void> disposeHandler() async {
    await _playbackEventSub?.cancel();
    await _currentIndexSub?.cancel();
    await _sequenceSub?.cancel();
    await _noisySub?.cancel();
    await _interruptionSub?.cancel();
    await _tracksSubject.close();
    await _currentTrackSubject.close();
    await _sourceLabelSubject.close();
    await _player.dispose();
  }
}
