import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import 'app_providers.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final storage = ref.watch(storageServiceProvider);
    final loaded = storage.loadSettings();
    _syncAudioPrefs(loaded);
    return loaded;
  }

  void _syncAudioPrefs(AppSettings settings) {
    try {
      final handler = ref.read(audioHandlerProvider);
      handler.updateAudioPreferences(
        gaplessPlayback: settings.gaplessPlayback,
        pauseOnHeadsetDisconnect: settings.pauseOnHeadsetDisconnect,
      );
    } catch (_) {
      // Safe during provider test overrides
    }
  }

  Future<void> _persist(AppSettings updated) async {
    state = updated;
    _syncAudioPrefs(updated);
    await ref.read(storageServiceProvider).saveSettings(updated);
  }

  Future<void> setMinDurationSeconds(int seconds) async {
    await _persist(state.copyWith(minDurationSeconds: seconds));
  }

  Future<void> toggleFolderIncluded(String folderPath) async {
    final excluded = List<String>.from(state.excludedFolders);
    if (excluded.contains(folderPath)) {
      excluded.remove(folderPath);
    } else {
      excluded.add(folderPath);
    }
    await _persist(state.copyWith(excludedFolders: excluded));
  }

  Future<void> setPreferExternalLrc(bool value) async {
    await _persist(state.copyWith(preferExternalLrc: value));
  }

  Future<void> setLyricFontSize(LyricFontSize size) async {
    await _persist(state.copyWith(lyricFontSize: size));
  }

  Future<void> setAutoScrollLyrics(bool value) async {
    await _persist(state.copyWith(autoScrollLyrics: value));
  }

  Future<void> setGaplessPlayback(bool value) async {
    await _persist(state.copyWith(gaplessPlayback: value));
  }

  Future<void> setPauseOnHeadsetDisconnect(bool value) async {
    await _persist(state.copyWith(pauseOnHeadsetDisconnect: value));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
