import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../providers/library_provider.dart';
import '../providers/playback_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork_image.dart';
import '../widgets/track_tile.dart';
import 'settings_screen.dart';

enum _HomeFilter { all, flac, lrc, recent }

enum _HomeSort { titleAsc, artistAsc, dateAddedDesc, durationDesc }

class HomeTab extends ConsumerStatefulWidget {
  final void Function(LocalAlbum album)? onOpenAlbum;

  const HomeTab({super.key, this.onOpenAlbum});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  _HomeFilter _filter = _HomeFilter.all;
  _HomeSort _sort = _HomeSort.titleAsc;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _sortLabel(_HomeSort sort) {
    switch (sort) {
      case _HomeSort.titleAsc:
        return 'Title A-Z';
      case _HomeSort.artistAsc:
        return 'Artist';
      case _HomeSort.dateAddedDesc:
        return 'Recently Added';
      case _HomeSort.durationDesc:
        return 'Duration';
    }
  }

  List<SongTrack> _applyFilterAndSort(List<SongTrack> input) {
    Iterable<SongTrack> result = input;
    switch (_filter) {
      case _HomeFilter.all:
        break;
      case _HomeFilter.flac:
        result = result.where(
          (t) =>
              t.fileExtension == '.flac' ||
              t.fileExtension == '.wav',
        );
        break;
      case _HomeFilter.lrc:
        result = result.where((t) => t.hasAnyLyrics);
        break;
      case _HomeFilter.recent:
        final list = result.toList()
          ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        result = list.take(40);
        break;
    }

    final sorted = result.toList();
    switch (_sort) {
      case _HomeSort.titleAsc:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case _HomeSort.artistAsc:
        sorted.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
        break;
      case _HomeSort.dateAddedDesc:
        sorted.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case _HomeSort.durationDesc:
        sorted.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final allTracks = ref.watch(visibleTracksProvider);
    final recentTracks = ref.watch(recentlyPlayedTracksProvider);
    final albums = ref.watch(localAlbumsProvider);
    final playlists = libState.playlists;

    final filteredTracks = _applyFilterAndSort(allTracks);
    final currentTrack = ref.watch(currentTrackProvider).value;
    final hasMiniPlayer = currentTrack != null;

    return Stack(
      children: [
        // Ambient Purple Stage Backlight
        Positioned(
          top: -60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAccent.withValues(alpha: 0.16),
              ),
            ),
          ),
        ),
        RefreshIndicator(
          color: AppColors.primaryAccent,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: () => ref.read(libraryProvider.notifier).rescanLibrary(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top App Header & Greeting
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/icon/appicon.jpg',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                'Home',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Rescan Quick Button + Track Count
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => ref
                                .read(libraryProvider.notifier)
                                .rescanLibrary(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.borderPurpleSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  libState.isScanning
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primaryAccent,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.sync_rounded,
                                          size: 16,
                                          color: AppColors.softLavender,
                                        ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${allTracks.length} tracks',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Settings',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryAccent
                                      .withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LOCAL STORAGE SYNC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              color: AppColors.tertiaryLilac,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _FilterChipButton(
                        label: 'All Files',
                        selected: _filter == _HomeFilter.all,
                        onTap: () =>
                            setState(() => _filter = _HomeFilter.all),
                      ),
                      _FilterChipButton(
                        label: 'FLAC Lossless',
                        selected: _filter == _HomeFilter.flac,
                        onTap: () =>
                            setState(() => _filter = _HomeFilter.flac),
                      ),
                      _FilterChipButton(
                        label: 'Has Lyrics',
                        selected: _filter == _HomeFilter.lrc,
                        onTap: () =>
                            setState(() => _filter = _HomeFilter.lrc),
                      ),
                      _FilterChipButton(
                        label: 'Recently Added',
                        selected: _filter == _HomeFilter.recent,
                        onTap: () =>
                            setState(() => _filter = _HomeFilter.recent),
                      ),
                    ],
                  ),
                ),
              ),

              // Section 1: Recently Played 2-Column Grid
              if (recentTracks.isNotEmpty || playlists.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recently Played',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${recentTracks.length} played',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tertiaryLilac,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentTracks.take(6).length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 3.05,
                          ),
                          itemBuilder: (context, index) {
                            final track = recentTracks[index];
                            return Material(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => ref
                                    .read(playbackControllerProvider)
                                    .playSingle(
                                      track,
                                      contextList: recentTracks,
                                      sourceLabel: 'Recently Played',
                                    ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderHairline,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ArtworkImage(
                                        track: track,
                                        size: 42,
                                        borderRadius: 8,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              track.folderName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // Section 2: Local Albums Horizontal Carousel
              if (albums.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              const Text(
                                'Your Local Albums',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.badgeContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'STORAGE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: AppColors.softLavender,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 206,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: albums.take(15).length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final album = albums[index];
                              final coverTrack = album.tracks.first;
                              return GestureDetector(
                                onTap: () {
                                  if (widget.onOpenAlbum != null) {
                                    widget.onOpenAlbum!(album);
                                  } else {
                                    ref
                                        .read(playbackControllerProvider)
                                        .playTracks(
                                          album.tracks,
                                          sourceLabel: album.name,
                                        );
                                  }
                                },
                                child: SizedBox(
                                  width: 140,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ArtworkImage(
                                            track: coverTrack,
                                            size: 140,
                                            borderRadius: 18,
                                            cacheSize: 360,
                                          ),
                                          Positioned(
                                            left: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors
                                                    .backgroundPrimary
                                                    .withValues(alpha: 0.86),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                album.primaryFormat,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      AppColors.softLavender,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        album.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        album.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${album.trackCount} ${album.trackCount == 1 ? 'track' : 'tracks'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Section 3 Header: All Local Tracks
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Local Tracks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      PopupMenuButton<_HomeSort>(
                        color: AppColors.surfaceCard,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (_) => _HomeSort.values
                            .map(
                              (s) => PopupMenuItem(
                                value: s,
                                child: Text(
                                  _sortLabel(s),
                                  style: TextStyle(
                                    color: s == _sort
                                        ? AppColors.primaryAccent
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sort_rounded,
                                size: 16,
                                color: AppColors.tertiaryLilac,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(_sort),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.tertiaryLilac,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (filteredTracks.isEmpty && !libState.isScanning)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 48,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No matching local tracks found',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add audio files (.mp3, .m4a, .aac, .opus, .flac, .wav, .ogg, etc.) to your device storage or adjust your minimum duration filter in Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    hasMiniPlayer ? 156 : 92,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = filteredTracks[index];
                        return TrackTile(
                          track: track,
                          onTap: () => ref
                              .read(playbackControllerProvider)
                              .playTracks(
                                filteredTracks,
                                initialIndex: index,
                                sourceLabel: 'All Local Tracks',
                              ),
                        );
                      },
                      childCount: filteredTracks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.primaryAccent : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primaryAccent
                  : AppColors.borderHairline,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
