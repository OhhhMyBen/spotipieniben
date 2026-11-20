import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../providers/playback_provider.dart';
import '../theme/app_theme.dart';
import '../utils/duration_formatter.dart';
import 'artwork_image.dart';
import 'mini_equalizer.dart';
import 'playlist_dialogs.dart';

class TrackTile extends ConsumerWidget {
  final SongTrack track;
  final VoidCallback onTap;
  final String? playlistIdToRemove;

  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.playlistIdToRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider).value;
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final isActive = currentTrack?.filePath == track.filePath;
    final badge = track.lyricsBadgeLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive
            ? AppColors.surfaceContainerHigh
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? AppColors.primaryAccent.withValues(alpha: 0.45)
                    : AppColors.borderHairline,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  if (isActive)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryAccent.withValues(alpha: 0.7),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isActive ? 12 : 10,
                      8,
                      6,
                      8,
                    ),
                    child: Row(
                      children: [
                        ArtworkImage(
                          track: track,
                          size: 46,
                          borderRadius: 10,
                          overlay: isActive
                              ? Container(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  alignment: Alignment.center,
                                  child: MiniEqualizer(
                                    isPlaying: isPlaying,
                                    color: AppColors.softLavender,
                                    height: 16,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? AppColors.softLavender
                                          : AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 5),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    track.formatBadge,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (badge != null) ...[
                          LyricsBadgePill(label: badge),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          formatDuration(track.duration),
                          style: AppTheme.tabularTimeStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => showTrackOptionsSheet(
                            context,
                            ref,
                            track,
                            playlistIdToRemove: playlistIdToRemove,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LyricsBadgePill extends StatelessWidget {
  final String label;

  const LyricsBadgePill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isLrc = label == 'LRC';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isLrc
            ? AppColors.badgeContainer.withValues(alpha: 0.7)
            : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLrc
              ? AppColors.primaryAccent.withValues(alpha: 0.55)
              : AppColors.borderHairline,
        ),
        boxShadow: isLrc
            ? [
                BoxShadow(
                  color: AppColors.primaryAccent.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: isLrc ? AppColors.softLavender : AppColors.textSecondary,
        ),
      ),
    );
  }
}
