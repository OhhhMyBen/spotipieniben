import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../providers/app_providers.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../utils/duration_formatter.dart';
import 'artwork_image.dart';

Future<void> showCreatePlaylistDialog(
  BuildContext context,
  WidgetRef ref, {
  SongTrack? initialTrack,
}) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New Playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Playlist name',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceContainer,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );

  if (name == null || name.trim().isEmpty) return;
  final created =
      await ref.read(libraryProvider.notifier).createPlaylist(name.trim());
  if (initialTrack != null) {
    await ref
        .read(libraryProvider.notifier)
        .addTrackToPlaylist(created.id, initialTrack);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created "${created.name}"')),
    );
  }
}

Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  SongTrack track,
) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final playlists =
            ref.watch(libraryProvider.select((l) => l.playlists));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add to Playlist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        showCreatePlaylistDialog(
                          context,
                          ref,
                          initialTrack: track,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No playlists yet. Tap "New" to create one.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (_, index) {
                        final playlist = playlists[index];
                        final contains =
                            playlist.trackPaths.contains(track.filePath);
                        return ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.queue_music_rounded,
                              color: AppColors.softLavender,
                            ),
                          ),
                          title: Text(
                            playlist.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${playlist.trackPaths.length} tracks',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: contains
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryAccent,
                                )
                              : null,
                          onTap: () async {
                            await ref
                                .read(libraryProvider.notifier)
                                .addTrackToPlaylist(playlist.id, track);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added to "${playlist.name}"',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> showSongInfoSheet(BuildContext context, SongTrack track) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ArtworkImage(track: track, size: 56, borderRadius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _infoRow('Album', track.album),
            _infoRow('Format', track.audioSpecLabel),
            _infoRow('Duration', formatDuration(track.duration)),
            _infoRow('Size', formatFileSize(track.sizeBytes)),
            _infoRow(
              'Lyrics',
              track.hasExternalLrc
                  ? 'External .LRC detected'
                  : (track.hasEmbeddedLyrics
                      ? 'Embedded ID3 tags'
                      : 'None detected'),
            ),
            _infoRow('File Path', track.filePath),
          ],
        ),
      ),
    ),
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showTrackOptionsSheet(
  BuildContext context,
  WidgetRef ref,
  SongTrack track, {
  String? playlistIdToRemove,
}) async {
  final isFav = ref
      .read(libraryProvider)
      .favoritePaths
      .contains(track.filePath);
  final handler = ref.read(audioHandlerProvider);

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ArtworkImage(track: track, size: 46, borderRadius: 10),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${track.artist} • ${track.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const Divider(color: AppColors.borderHairline),
            ListTile(
              leading: const Icon(
                Icons.playlist_play_rounded,
                color: AppColors.softLavender,
              ),
              title: const Text('Play Next'),
              onTap: () async {
                Navigator.pop(ctx);
                await handler.playNext(track);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Playing "${track.title}" next')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.add_to_queue_rounded,
                color: AppColors.softLavender,
              ),
              title: const Text('Add to Queue'),
              onTap: () async {
                Navigator.pop(ctx);
                await handler.addToQueue(track);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added "${track.title}" to queue')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_rounded,
                color: AppColors.softLavender,
              ),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(ctx);
                showAddToPlaylistSheet(context, ref, track);
              },
            ),
            if (playlistIdToRemove != null)
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Remove from Playlist',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(libraryProvider.notifier)
                      .removeTrackFromPlaylist(
                        playlistIdToRemove,
                        track.filePath,
                      );
                },
              ),
            ListTile(
              leading: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: AppColors.primaryAccent,
              ),
              title: Text(isFav ? 'Remove from Liked Songs' : 'Like Song'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(libraryProvider.notifier).toggleFavorite(track);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.textSecondary,
              ),
              title: const Text('Song Info'),
              onTap: () {
                Navigator.pop(ctx);
                showSongInfoSheet(context, track);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
