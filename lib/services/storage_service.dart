import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/song_track.dart';

class StorageService {
  static const String _settingsKey = 'aura_settings_v1';
  static const String _favoritesKey = 'aura_favorites_v1';
  static const String _recentlyPlayedKey = 'aura_recent_tracks_v1';
  static const String _playlistsKey = 'aura_playlists_v1';
  static const String _customLrcMapKey = 'aura_custom_lrc_v1';
  static const String _recentSearchesKey = 'aura_recent_searches_v1';
  static const String _id3LyricsCacheKey = 'aura_id3_lyrics_cache_v1';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Settings
  AppSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // Favorites (Liked Songs)
  Set<String> loadFavorites() {
    final list = _prefs.getStringList(_favoritesKey) ?? const [];
    return list.toSet();
  }

  Future<void> saveFavorites(Set<String> trackPaths) async {
    await _prefs.setStringList(_favoritesKey, trackPaths.toList());
  }

  // Recently Played (ordered most recent first)
  List<String> loadRecentlyPlayed() {
    return _prefs.getStringList(_recentlyPlayedKey) ?? const [];
  }

  Future<void> saveRecentlyPlayed(List<String> trackPaths) async {
    await _prefs.setStringList(
      _recentlyPlayedKey,
      trackPaths.take(40).toList(),
    );
  }

  // Custom Local Playlists
  List<LocalPlaylist> loadPlaylists() {
    final raw = _prefs.getString(_playlistsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => LocalPlaylist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePlaylists(List<LocalPlaylist> playlists) async {
    final encoded = jsonEncode(playlists.map((e) => e.toJson()).toList());
    await _prefs.setString(_playlistsKey, encoded);
  }

  // Custom imported .lrc file paths mapped by track filePath
  Map<String, String> loadCustomLrcMap() {
    final raw = _prefs.getString(_customLrcMapKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveCustomLrcMapping(String trackPath, String lrcPath) async {
    final map = Map<String, String>.from(loadCustomLrcMap());
    map[trackPath] = lrcPath;
    await _prefs.setString(_customLrcMapKey, jsonEncode(map));
  }

  // Recent Searches
  List<String> loadRecentSearches() {
    return _prefs.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<void> saveRecentSearches(List<String> queries) async {
    await _prefs.setStringList(_recentSearchesKey, queries.take(10).toList());
  }

  // Cached ID3 lyrics flags: trackPath -> 'synced' | 'plain' | 'none'
  Map<String, String> loadId3LyricsFlags() {
    final raw = _prefs.getString(_id3LyricsCacheKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveId3LyricsFlags(Map<String, String> flags) async {
    await _prefs.setString(_id3LyricsCacheKey, jsonEncode(flags));
  }

  Future<void> clearMetadataCache() async {
    await _prefs.remove(_id3LyricsCacheKey);
  }
}
