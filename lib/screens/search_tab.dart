import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../providers/library_provider.dart';
import '../providers/playback_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_image.dart';
import '../widgets/track_tile.dart';

enum SearchCategory { all, songs, artists, albums, hasLyrics, lossless }

class SearchTab extends ConsumerStatefulWidget {
  final void Function(LocalAlbum album)? onOpenAlbum;
  final void Function(LocalArtist artist)? onOpenArtist;

  const SearchTab({
    super.key,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final TextEditingController _controller = TextEditingController();
  SearchCategory _category = SearchCategory.all;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _categoryLabel(SearchCategory c) {
    switch (c) {
      case SearchCategory.all:
        return 'All';
      case SearchCategory.songs:
        return 'Songs';
      case SearchCategory.artists:
        return 'Artists';
      case SearchCategory.albums:
        return 'Albums';
      case SearchCategory.hasLyrics:
        return 'Has Lyrics';
      case SearchCategory.lossless:
        return 'Lossless';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTracks = ref.watch(visibleTracksProvider);
    final albums = ref.watch(localAlbumsProvider);
    final artists = ref.watch(localArtistsProvider);
    final recentSearches =
        ref.watch(libraryProvider.select((l) => l.recentSearches));
    final hasMiniPlayer = ref.watch(currentTrackProvider).value != null;

    final q = _query.trim().toLowerCase();

    final matchingSongs = allTracks.where((t) {
      if (_category == SearchCategory.hasLyrics && !t.hasAnyLyrics) {
        return false;
      }
      if (_category == SearchCategory.lossless &&
          t.fileExtension != '.flac' &&
          t.fileExtension != '.wav') {
        return false;
      }
      if (q.isEmpty) {
        return _category == SearchCategory.hasLyrics ||
            _category == SearchCategory.lossless;
      }
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();

    final matchingArtists = artists.where((a) {
      if (q.isEmpty) return false;
      return a.name.toLowerCase().contains(q);
    }).toList();

    final matchingAlbums = albums.where((a) {
      if (q.isEmpty) return false;
      return a.name.toLowerCase().contains(q) ||
          a.artist.toLowerCase().contains(q);
    }).toList();

    final showResults = q.isNotEmpty ||
        _category == SearchCategory.hasLyrics ||
        _category == SearchCategory.lossless;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        hasMiniPlayer ? 156 : 92,
      ),
      children: [
        const Text(
          'SPOTIPIENIBEN',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.softLavender,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Search',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        // Search Input Bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: q.isNotEmpty
                  ? AppColors.primaryAccent.withValues(alpha: 0.6)
                  : AppColors.borderHairline,
            ),
            boxShadow: q.isNotEmpty
                ? [
                    BoxShadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.18),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                ref.read(libraryProvider.notifier).addRecentSearch(value);
              }
            },
            decoration: InputDecoration(
              hintText: 'Search local songs, artists, or albums...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryAccent,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Category Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: SearchCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, idx) {
              final cat = SearchCategory.values[idx];
              final selected = _category == cat;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _category = cat),
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
                    _categoryLabel(cat),
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

        if (!showResults) ...[
          if (recentSearches.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECENT QUERIES',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: AppColors.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(libraryProvider.notifier)
                      .clearRecentSearches(),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches
                  .map(
                    (term) => InputChip(
                      label: Text(
                        term,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                      avatar: const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      backgroundColor: AppColors.surfaceCard,
                      side: const BorderSide(color: AppColors.borderHairline),
                      deleteIconColor: AppColors.textMuted,
                      onPressed: () {
                        _controller.text = term;
                        setState(() => _query = term);
                      },
                      onDeleted: () => ref
                          .read(libraryProvider.notifier)
                          .removeRecentSearch(term),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'Browse Collections',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Instant offline filtering across your device library',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _BrowseCollectionCard(
                title: 'Synced Lyrics Hub',
                subtitle:
                    '${allTracks.where((t) => t.hasAnyLyrics).length} tracks with lyrics',
                badge: 'LRC / ID3',
                icon: Icons.lyrics_rounded,
                gradient: const [
                  AppColors.lyricsCardSurface,
                  AppColors.surfaceCard,
                ],
                onTap: () =>
                    setState(() => _category = SearchCategory.hasLyrics),
              ),
              _BrowseCollectionCard(
                title: 'Lossless & Hi-Res',
                subtitle:
                    '${allTracks.where((t) => t.fileExtension == '.flac' || t.fileExtension == '.wav').length} FLAC/WAV files',
                badge: 'LOSSLESS',
                icon: Icons.album_rounded,
                gradient: const [
                  AppColors.surfaceDeepPlum,
                  AppColors.surfaceCard,
                ],
                onTap: () =>
                    setState(() => _category = SearchCategory.lossless),
              ),
              _BrowseCollectionCard(
                title: 'Local Artists',
                subtitle: '${artists.length} artists indexed',
                badge: 'ARTISTS',
                icon: Icons.person_rounded,
                gradient: const [
                  AppColors.surfaceContainerHigh,
                  AppColors.surfaceCard,
                ],
                onTap: () =>
                    setState(() => _category = SearchCategory.artists),
              ),
              _BrowseCollectionCard(
                title: 'Local Albums',
                subtitle: '${albums.length} albums stored',
                badge: 'ALBUMS',
                icon: Icons.library_music_rounded,
                gradient: const [
                  AppColors.badgeContainer,
                  AppColors.surfaceCard,
                ],
                onTap: () =>
                    setState(() => _category = SearchCategory.albums),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 18),
          if ((_category == SearchCategory.all ||
                  _category == SearchCategory.artists) &&
              matchingArtists.isNotEmpty) ...[
            const Text(
              'Artists',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.softLavender,
              ),
            ),
            const SizedBox(height: 8),
            ...matchingArtists.take(5).map(
                  (artist) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surfaceDeepPlum,
                      child: Text(
                        artist.name.isNotEmpty
                            ? artist.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.softLavender,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      artist.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${artist.tracks.length} songs • ${artist.albums.length} albums',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      ref
                          .read(libraryProvider.notifier)
                          .addRecentSearch(_query);
                      if (widget.onOpenArtist != null) {
                        widget.onOpenArtist!(artist);
                      } else {
                        ref.read(playbackControllerProvider).playTracks(
                              artist.tracks,
                              sourceLabel: artist.name,
                            );
                      }
                    },
                  ),
                ),
            const SizedBox(height: 12),
          ],
          if ((_category == SearchCategory.all ||
                  _category == SearchCategory.albums) &&
              matchingAlbums.isNotEmpty) ...[
            const Text(
              'Albums',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.softLavender,
              ),
            ),
            const SizedBox(height: 8),
            ...matchingAlbums.take(5).map(
                  (album) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ArtworkImage(
                      track: album.tracks.first,
                      size: 46,
                      borderRadius: 10,
                    ),
                    title: Text(
                      album.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${album.artist} • ${album.trackCount} tracks',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      ref
                          .read(libraryProvider.notifier)
                          .addRecentSearch(_query);
                      if (widget.onOpenAlbum != null) {
                        widget.onOpenAlbum!(album);
                      } else {
                        ref.read(playbackControllerProvider).playTracks(
                              album.tracks,
                              sourceLabel: album.name,
                            );
                      }
                    },
                  ),
                ),
            const SizedBox(height: 12),
          ],
          if (_category == SearchCategory.all ||
              _category == SearchCategory.songs ||
              _category == SearchCategory.hasLyrics ||
              _category == SearchCategory.lossless) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _category == SearchCategory.hasLyrics
                      ? 'Tracks with Lyrics (${matchingSongs.length})'
                      : _category == SearchCategory.lossless
                          ? 'Lossless FLAC / WAV (${matchingSongs.length})'
                          : 'Songs (${matchingSongs.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.softLavender,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (matchingSongs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No matching local tracks',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...List.generate(matchingSongs.length, (idx) {
                final track = matchingSongs[idx];
                return TrackTile(
                  track: track,
                  onTap: () {
                    if (_query.trim().isNotEmpty) {
                      ref
                          .read(libraryProvider.notifier)
                          .addRecentSearch(_query);
                    }
                    ref.read(playbackControllerProvider).playTracks(
                          matchingSongs,
                          initialIndex: idx,
                          sourceLabel: 'Search Results',
                        );
                  },
                );
              }),
          ],
        ],
      ],
    );
  }
}

class _BrowseCollectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _BrowseCollectionCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: AppColors.borderPurpleSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundPrimary.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.softLavender,
                    ),
                  ),
                ),
                Icon(icon, color: AppColors.softLavender, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
