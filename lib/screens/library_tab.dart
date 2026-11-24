import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../providers/library_provider.dart';
import '../providers/playback_provider.dart';
import '../theme/app_theme.dart';
import '../utils/duration_formatter.dart';
import '../widgets/artwork_image.dart';
import '../widgets/playlist_dialogs.dart';
import '../widgets/track_tile.dart';

enum LibraryFilterTab { playlists, liked, artists, albums, folders }

enum _DetailCollectionKind { playlist, album, artist, folder, lyrics }

class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => LibraryTabState();
}

class LibraryTabState extends ConsumerState<LibraryTab> {
  LibraryFilterTab _activeTab = LibraryFilterTab.playlists;
  _DetailCollectionKind? _detailKind;
  String? _detailTitle;
  String? _detailKey;
  String? _detailPlaylistId;

  void openAlbum(LocalAlbum album) {
    setState(() {
      _activeTab = LibraryFilterTab.albums;
      _detailKind = _DetailCollectionKind.album;
      _detailTitle = album.name;
      _detailKey = '${album.name}__${album.artist}';
      _detailPlaylistId = null;
    });
  }

  void openArtist(LocalArtist artist) {
    setState(() {
      _activeTab = LibraryFilterTab.artists;
      _detailKind = _DetailCollectionKind.artist;
      _detailTitle = artist.name;
      _detailKey = artist.name;
      _detailPlaylistId = null;
    });
  }

  String _tabLabel(LibraryFilterTab tab) {
    switch (tab) {
      case LibraryFilterTab.playlists:
        return 'Playlists';
      case LibraryFilterTab.liked:
        return 'Liked Songs';
      case LibraryFilterTab.artists:
        return 'Artists';
      case LibraryFilterTab.albums:
        return 'Albums';
      case LibraryFilterTab.folders:
        return 'Folders';
    }
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final allTracks = ref.watch(visibleTracksProvider);
    final likedTracks = ref.watch(likedTracksProvider);
    final albums = ref.watch(localAlbumsProvider);
    final artists = ref.watch(localArtistsProvider);
    final folders = ref.watch(localFoldersProvider);
    final hasMiniPlayer = ref.watch(currentTrackProvider).value != null;

    final totalBytes =
        allTracks.fold<int>(0, (sum, t) => sum + t.sizeBytes);
    final lrcCount = allTracks.where((t) => t.hasAnyLyrics).length;

    if (_detailKind != null && _detailTitle != null) {
      final List<SongTrack> resolvedTracks = switch (_detailKind!) {
        _DetailCollectionKind.playlist => const <SongTrack>[],
        _DetailCollectionKind.album => albums
                .where((a) => '${a.name}__${a.artist}' == _detailKey)
                .firstOrNull
                ?.tracks ??
            const <SongTrack>[],
        _DetailCollectionKind.artist => artists
                .where((a) => a.name == _detailKey)
                .firstOrNull
                ?.tracks ??
            const <SongTrack>[],
        _DetailCollectionKind.folder => folders
                .where((f) => f.path == _detailKey)
                .firstOrNull
                ?.tracks ??
            const <SongTrack>[],
        _DetailCollectionKind.lyrics =>
            allTracks.where((t) => t.hasAnyLyrics).toList(),
      };
      return _DetailCollectionView(
        title: _detailTitle!,
        tracks: resolvedTracks,
        playlistId: _detailPlaylistId,
        hasMiniPlayer: hasMiniPlayer,
        onBack: () => setState(() {
          _detailKind = null;
          _detailTitle = null;
          _detailKey = null;
          _detailPlaylistId = null;
        }),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        hasMiniPlayer ? 156 : 92,
      ),
      children: [
        // Top Header + Storage Pill + New Playlist
        Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPOTIPIENIBEN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.softLavender,
                  ),
                ),
                Text(
                  'Your Library',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Rescan',
              onPressed: () =>
                  ref.read(libraryProvider.notifier).rescanLibrary(),
              icon: libState.isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryAccent,
                      ),
                    )
                  : const Icon(
                      Icons.sync_rounded,
                      color: AppColors.softLavender,
                    ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () => showCreatePlaylistDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'New',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Storage Summary Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderHairline),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sd_storage_rounded,
                  color: AppColors.softLavender,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LOCAL LIBRARY INDEXED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.softLavender,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${allTracks.length} songs • ${formatFileSize(totalBytes)} • $lrcCount with lyrics',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Smart Collections Bento Row
        Row(
          children: [
            Expanded(
              child: _SmartTile(
                icon: Icons.favorite_rounded,
                title: 'Liked',
                count: '${likedTracks.length} songs',
                accent: AppColors.primaryAccent,
                onTap: () =>
                    setState(() => _activeTab = LibraryFilterTab.liked),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmartTile(
                icon: Icons.lyrics_rounded,
                title: 'Lyrics',
                count: '$lrcCount matched',
                accent: AppColors.tertiaryLilac,
                onTap: () => setState(() {
                  _detailKind = _DetailCollectionKind.lyrics;
                  _detailTitle = 'Tracks with Lyrics';
                  _detailKey = null;
                  _detailPlaylistId = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmartTile(
                icon: Icons.folder_rounded,
                title: 'Folders',
                count: '${folders.length} dirs',
                accent: AppColors.softLavender,
                onTap: () =>
                    setState(() => _activeTab = LibraryFilterTab.folders),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Pills
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: LibraryFilterTab.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, idx) {
              final tab = LibraryFilterTab.values[idx];
              final selected = _activeTab == tab;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _activeTab = tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryAccent
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryAccent
                          : AppColors.borderHairline,
                    ),
                  ),
                  child: Text(
                    _tabLabel(tab),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Tab Body
        switch (_activeTab) {
          LibraryFilterTab.playlists => _buildPlaylistsSection(
              libState.playlists,
              allTracks,
            ),
          LibraryFilterTab.liked => _buildLikedSection(likedTracks),
          LibraryFilterTab.artists => _buildArtistsSection(artists),
          LibraryFilterTab.albums => _buildAlbumsSection(albums),
          LibraryFilterTab.folders => _buildFoldersSection(folders),
        },
      ],
    );
  }

  Widget _buildPlaylistsSection(
    List<LocalPlaylist> playlists,
    List<SongTrack> allTracks,
  ) {
    final byPath = {for (final t in allTracks) t.filePath: t};
    if (playlists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(
              Icons.queue_music_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            const Text(
              'No custom playlists yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create offline playlists and add any local tracks from your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => showCreatePlaylistDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Playlist'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: playlists.map((pl) {
        final plTracks = pl.trackPaths
            .map((p) => byPath[p])
            .whereType<SongTrack>()
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderHairline),
              ),
              leading: plTracks.isNotEmpty
                  ? ArtworkImage(
                      track: plTracks.first,
                      size: 48,
                      borderRadius: 10,
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDeepPlum,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: AppColors.softLavender,
                      ),
                    ),
              title: Text(
                pl.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${plTracks.length} ${plTracks.length == 1 ? 'song' : 'songs'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.primaryAccent,
                      size: 32,
                    ),
                    onPressed: plTracks.isEmpty
                        ? null
                        : () => ref.read(playbackControllerProvider).playTracks(
                              plTracks,
                              sourceLabel: pl.name,
                            ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => ref
                        .read(libraryProvider.notifier)
                        .deletePlaylist(pl.id),
                  ),
                ],
              ),
              onTap: () => setState(() {
                _detailKind = _DetailCollectionKind.playlist;
                _detailTitle = pl.name;
                _detailKey = pl.id;
                _detailPlaylistId = pl.id;
              }),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLikedSection(List<SongTrack> likedTracks) {
    if (likedTracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            'Tap the heart icon on any track to save it to Liked Songs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: List.generate(likedTracks.length, (i) {
        final track = likedTracks[i];
        return TrackTile(
          track: track,
          onTap: () => ref.read(playbackControllerProvider).playTracks(
                likedTracks,
                initialIndex: i,
                sourceLabel: 'Liked Songs',
              ),
        );
      }),
    );
  }

  Widget _buildArtistsSection(List<LocalArtist> artists) {
    return Column(
      children: artists.map((artist) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderHairline),
              ),
              leading: ArtworkImage(
                track: artist.tracks.first,
                size: 48,
                borderRadius: 24,
              ),
              title: Text(
                artist.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${artist.tracks.length} tracks • ${artist.albums.length} albums',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () => openArtist(artist),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlbumsSection(List<LocalAlbum> albums) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: albums.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final album = albums[index];
        return GestureDetector(
          onTap: () => openAlbum(album),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: ArtworkImage(
                      track: album.tracks.first,
                      size: 150,
                      borderRadius: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${album.artist} • ${album.trackCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFoldersSection(List<LocalFolder> folders) {
    return Column(
      children: folders.map((folder) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderHairline),
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.softLavender,
                ),
              ),
              title: Text(
                folder.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${folder.path} • ${folder.tracks.length} files',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.primaryAccent,
                  size: 32,
                ),
                onPressed: () => ref.read(playbackControllerProvider).playTracks(
                      folder.tracks,
                      sourceLabel: folder.name,
                    ),
              ),
              onTap: () => setState(() {
                _detailKind = _DetailCollectionKind.folder;
                _detailTitle = folder.name;
                _detailKey = folder.path;
                _detailPlaylistId = null;
              }),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SmartTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;
  final Color accent;
  final VoidCallback onTap;

  const _SmartTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            Text(
              count,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCollectionView extends ConsumerWidget {
  final String title;
  final List<SongTrack> tracks;
  final String? playlistId;
  final bool hasMiniPlayer;
  final VoidCallback onBack;

  const _DetailCollectionView({
    required this.title,
    required this.tracks,
    required this.playlistId,
    required this.hasMiniPlayer,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep playlist tracks reactive when removing items
    final liveTracks = playlistId != null
        ? (() {
            final playlists =
                ref.watch(libraryProvider.select((l) => l.playlists));
            final pl = playlists.where((p) => p.id == playlistId).firstOrNull;
            if (pl == null) return <SongTrack>[];
            final all = ref.watch(visibleTracksProvider);
            final map = {for (final t in all) t.filePath: t};
            return pl.trackPaths
                .map((p) => map[p])
                .whereType<SongTrack>()
                .toList();
          })()
        : tracks;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${liveTracks.length} tracks',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (liveTracks.isNotEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () =>
                      ref.read(playbackControllerProvider).playTracks(
                            liveTracks,
                            sourceLabel: title,
                          ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Play All'),
                ),
            ],
          ),
        ),
        Expanded(
          child: liveTracks.isEmpty
              ? const Center(
                  child: Text(
                    'No tracks in this collection',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    hasMiniPlayer ? 156 : 92,
                  ),
                  itemCount: liveTracks.length,
                  itemBuilder: (_, idx) {
                    final track = liveTracks[idx];
                    return TrackTile(
                      track: track,
                      playlistIdToRemove: playlistId,
                      onTap: () =>
                          ref.read(playbackControllerProvider).playTracks(
                                liveTracks,
                                initialIndex: idx,
                                sourceLabel: title,
                              ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
