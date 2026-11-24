import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../services/permissions_service.dart';
import 'app_providers.dart';
import 'settings_provider.dart';

class LibraryState {
  final AudioPermissionResult permissionStatus;
  final bool isLoading;
  final bool isScanning;
  final List<SongTrack> allScannedTracks;
  final List<String> discoveredFolders;
  final Set<String> favoritePaths;
  final List<String> recentlyPlayedPaths;
  final List<LocalPlaylist> playlists;
  final List<String> recentSearches;
  final DateTime? lastScannedAt;
  final String? errorMessage;

  const LibraryState({
    this.permissionStatus = AudioPermissionResult.denied,
    this.isLoading = true,
    this.isScanning = false,
    this.allScannedTracks = const [],
    this.discoveredFolders = const [],
    this.favoritePaths = const {},
    this.recentlyPlayedPaths = const [],
    this.playlists = const [],
    this.recentSearches = const [],
    this.lastScannedAt,
    this.errorMessage,
  });

  LibraryState copyWith({
    AudioPermissionResult? permissionStatus,
    bool? isLoading,
    bool? isScanning,
    List<SongTrack>? allScannedTracks,
    List<String>? discoveredFolders,
    Set<String>? favoritePaths,
    List<String>? recentlyPlayedPaths,
    List<LocalPlaylist>? playlists,
    List<String>? recentSearches,
    DateTime? lastScannedAt,
    String? errorMessage,
  }) {
    return LibraryState(
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      allScannedTracks: allScannedTracks ?? this.allScannedTracks,
      discoveredFolders: discoveredFolders ?? this.discoveredFolders,
      favoritePaths: favoritePaths ?? this.favoritePaths,
      recentlyPlayedPaths: recentlyPlayedPaths ?? this.recentlyPlayedPaths,
      playlists: playlists ?? this.playlists,
      recentSearches: recentSearches ?? this.recentSearches,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      errorMessage: errorMessage,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  bool _initialized = false;
  bool _pendingRescan = false;

  @override
  LibraryState build() {
    final storage = ref.watch(storageServiceProvider);
    final initialState = LibraryState(
      favoritePaths: storage.loadFavorites(),
      recentlyPlayedPaths: storage.loadRecentlyPlayed(),
      playlists: storage.loadPlaylists(),
      recentSearches: storage.loadRecentSearches(),
    );

    if (!_initialized) {
      _initialized = true;
      Future.microtask(initLibrary);
    }

    return initialState;
  }

  Future<void> initLibrary() async {
    final perms = ref.read(permissionsServiceProvider);
    var status = await perms.checkPermission();
    if (status != AudioPermissionResult.granted) {
      status = await perms.requestAudioPermission();
    }

    state = state.copyWith(
      permissionStatus: status,
      isLoading: false,
    );

    if (status == AudioPermissionResult.granted) {
      await rescanLibrary();
    }
  }

  Future<void> requestPermissionAndScan() async {
    final perms = ref.read(permissionsServiceProvider);
    final status = await perms.requestAudioPermission();
    state = state.copyWith(permissionStatus: status, isLoading: false);
    if (status == AudioPermissionResult.granted) {
      await rescanLibrary();
    }
  }

  Future<void> refreshPermissionStatus() async {
    final perms = ref.read(permissionsServiceProvider);
    final status = await perms.checkPermission();
    state = state.copyWith(permissionStatus: status);
    if (status == AudioPermissionResult.granted &&
        state.allScannedTracks.isEmpty) {
      await rescanLibrary();
    }
  }

  Future<void> rescanLibrary() async {
    if (state.isScanning) {
      _pendingRescan = true;
      return;
    }
    state = state.copyWith(isScanning: true, errorMessage: null);

    try {
      final settings = ref.read(settingsProvider);
      final scanner = ref.read(libraryScannerServiceProvider);
      final result = await scanner.scanDeviceLibrary(
        minDurationSeconds: settings.minDurationSeconds,
      );

      state = state.copyWith(
        isScanning: false,
        isLoading: false,
        allScannedTracks: result.allTracks,
        discoveredFolders: result.discoveredFolders,
        lastScannedAt: DateTime.now(),
      );

      // Enrich embedded ID3 lyrics flags asynchronously for list badges
      unawaited(_enrichId3Badges(result.allTracks));
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        isLoading: false,
        errorMessage: 'Failed to scan local audio: $e',
      );
    } finally {
      if (_pendingRescan) {
        _pendingRescan = false;
        unawaited(rescanLibrary());
      }
    }
  }

  Future<void> _enrichId3Badges(List<SongTrack> tracks) async {
    if (tracks.isEmpty) return;
    final scanner = ref.read(libraryScannerServiceProvider);
    await scanner.indexId3LyricsFlags(
      tracks,
      onBatchReady: (flags) {
        final updated = state.allScannedTracks.map((t) {
          final flag = flags[t.filePath];
          if (flag == null) return t;
          return t.copyWith(
            hasEmbeddedLyrics: flag == 'plain' || flag == 'synced',
            hasEmbeddedSyncedLyrics: flag == 'synced',
          );
        }).toList();
        state = state.copyWith(allScannedTracks: updated);
      },
    );
  }

  void markTrackHasLrc(String filePath) {
    final updated = state.allScannedTracks.map((t) {
      if (t.filePath == filePath) {
        return t.copyWith(hasExternalLrc: true);
      }
      return t;
    }).toList();
    state = state.copyWith(allScannedTracks: updated);
  }

  Future<void> toggleFavorite(SongTrack track) async {
    final favs = Set<String>.from(state.favoritePaths);
    if (favs.contains(track.filePath)) {
      favs.remove(track.filePath);
    } else {
      favs.add(track.filePath);
    }
    state = state.copyWith(favoritePaths: favs);
    await ref.read(storageServiceProvider).saveFavorites(favs);
  }

  Future<void> recordPlayed(SongTrack track) async {
    final recent = List<String>.from(state.recentlyPlayedPaths);
    recent.remove(track.filePath);
    recent.insert(0, track.filePath);
    final trimmed = recent.take(40).toList();
    state = state.copyWith(recentlyPlayedPaths: trimmed);
    await ref.read(storageServiceProvider).saveRecentlyPlayed(trimmed);
  }

  Future<LocalPlaylist> createPlaylist(String name) async {
    final cleanName = name.trim();
    final playlist = LocalPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: cleanName.isEmpty ? 'Untitled Playlist' : cleanName,
      trackPaths: const [],
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final updated = [playlist, ...state.playlists];
    state = state.copyWith(playlists: updated);
    await ref.read(storageServiceProvider).savePlaylists(updated);
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final updated =
        state.playlists.where((p) => p.id != playlistId).toList();
    state = state.copyWith(playlists: updated);
    await ref.read(storageServiceProvider).savePlaylists(updated);
  }

  Future<void> addTrackToPlaylist(String playlistId, SongTrack track) async {
    final updated = state.playlists.map((p) {
      if (p.id != playlistId) return p;
      if (p.trackPaths.contains(track.filePath)) return p;
      return p.copyWith(trackPaths: [...p.trackPaths, track.filePath]);
    }).toList();
    state = state.copyWith(playlists: updated);
    await ref.read(storageServiceProvider).savePlaylists(updated);
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackPath,
  ) async {
    final updated = state.playlists.map((p) {
      if (p.id != playlistId) return p;
      return p.copyWith(
        trackPaths: p.trackPaths.where((path) => path != trackPath).toList(),
      );
    }).toList();
    state = state.copyWith(playlists: updated);
    await ref.read(storageServiceProvider).savePlaylists(updated);
  }

  Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final list = List<String>.from(state.recentSearches);
    list.removeWhere((e) => e.toLowerCase() == clean.toLowerCase());
    list.insert(0, clean);
    final trimmed = list.take(8).toList();
    state = state.copyWith(recentSearches: trimmed);
    await ref.read(storageServiceProvider).saveRecentSearches(trimmed);
  }

  Future<void> removeRecentSearch(String query) async {
    final list =
        state.recentSearches.where((e) => e != query).toList();
    state = state.copyWith(recentSearches: list);
    await ref.read(storageServiceProvider).saveRecentSearches(list);
  }

  Future<void> clearRecentSearches() async {
    state = state.copyWith(recentSearches: const []);
    await ref.read(storageServiceProvider).saveRecentSearches(const []);
  }
}

final libraryProvider =
    NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);

/// Active library tracks after applying `excludedFolders` from settings.
final visibleTracksProvider = Provider<List<SongTrack>>((ref) {
  final lib = ref.watch(libraryProvider);
  final excluded = ref.watch(
    settingsProvider.select((s) => s.excludedFolders.toSet()),
  );
  if (excluded.isEmpty) return lib.allScannedTracks;
  return lib.allScannedTracks
      .where((t) => !excluded.contains(t.folderPath))
      .toList();
});

final likedTracksProvider = Provider<List<SongTrack>>((ref) {
  final tracks = ref.watch(visibleTracksProvider);
  final favs = ref.watch(libraryProvider.select((l) => l.favoritePaths));
  return tracks.where((t) => favs.contains(t.filePath)).toList();
});

final recentlyPlayedTracksProvider = Provider<List<SongTrack>>((ref) {
  final tracks = ref.watch(visibleTracksProvider);
  final recentPaths =
      ref.watch(libraryProvider.select((l) => l.recentlyPlayedPaths));
  final byPath = {for (final t in tracks) t.filePath: t};
  return recentPaths
      .map((path) => byPath[path])
      .whereType<SongTrack>()
      .toList();
});

final localAlbumsProvider = Provider<List<LocalAlbum>>((ref) {
  final tracks = ref.watch(visibleTracksProvider);
  final map = <String, List<SongTrack>>{};
  for (final t in tracks) {
    final key = '${t.album}__${t.artist}';
    map.putIfAbsent(key, () => []).add(t);
  }
  final albums = map.values.map((group) {
    final first = group.first;
    return LocalAlbum(
      name: first.album,
      artist: first.artist,
      albumId: first.albumId,
      tracks: group,
    );
  }).toList();
  albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return albums;
});

final localArtistsProvider = Provider<List<LocalArtist>>((ref) {
  final tracks = ref.watch(visibleTracksProvider);
  final map = <String, List<SongTrack>>{};
  for (final t in tracks) {
    map.putIfAbsent(t.artist, () => []).add(t);
  }
  final artists = map.entries.map((entry) {
    return LocalArtist(
      name: entry.key,
      tracks: entry.value,
      albums: entry.value.map((e) => e.album).toSet(),
    );
  }).toList();
  artists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return artists;
});

final localFoldersProvider = Provider<List<LocalFolder>>((ref) {
  final tracks = ref.watch(visibleTracksProvider);
  final map = <String, List<SongTrack>>{};
  for (final t in tracks) {
    map.putIfAbsent(t.folderPath, () => []).add(t);
  }
  final folders = map.entries.map((entry) {
    final first = entry.value.first;
    return LocalFolder(
      path: entry.key,
      name: first.folderName,
      tracks: entry.value,
    );
  }).toList();
  folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return folders;
});
