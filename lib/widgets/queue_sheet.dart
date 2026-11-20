import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/playback_provider.dart';
import '../theme/app_theme.dart';
import '../utils/duration_formatter.dart';
import 'artwork_image.dart';
import 'mini_equalizer.dart';

Future<void> showQueueSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => _QueueSheetBody(
        scrollController: scrollController,
      ),
    ),
  );
}

class _QueueSheetBody extends ConsumerWidget {
  final ScrollController scrollController;

  const _QueueSheetBody({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueTracksProvider).value ?? const [];
    final currentTrack = ref.watch(currentTrackProvider).value;
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final sourceLabel =
        ref.watch(sourceLabelProvider).value ?? 'Local Storage';
    final handler = ref.read(audioHandlerProvider);

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Up Next Queue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${queue.length} tracks • From $sourceLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Shuffle Queue',
                onPressed: () => handler.toggleShuffle(),
                icon: const Icon(
                  Icons.shuffle_rounded,
                  color: AppColors.softLavender,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.borderHairline, height: 1),
        Expanded(
          child: queue.isEmpty
              ? const Center(
                  child: Text(
                    'Queue is empty',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ReorderableListView.builder(
                  scrollController: scrollController,
                  itemCount: queue.length,
                  onReorderItem: (oldIndex, newIndex) {
                    handler.reorderQueue(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final isActive = currentTrack?.filePath == track.filePath;
                    return Dismissible(
                      key: ValueKey('${track.filePath}_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppColors.error.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                      ),
                      onDismissed: (_) => handler.removeFromQueue(index),
                      child: ListTile(
                        onTap: () => handler.skipToQueueItem(index),
                        tileColor: isActive
                            ? AppColors.primaryAccent.withValues(alpha: 0.14)
                            : Colors.transparent,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                Icons.drag_handle_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ArtworkImage(
                              track: track,
                              size: 42,
                              borderRadius: 8,
                              overlay: isActive
                                  ? Container(
                                      color:
                                          Colors.black.withValues(alpha: 0.5),
                                      alignment: Alignment.center,
                                      child: MiniEqualizer(
                                        isPlaying: isPlaying,
                                        color: AppColors.softLavender,
                                        height: 14,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isActive
                                ? AppColors.softLavender
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          formatDuration(track.duration),
                          style: AppTheme.tabularTimeStyle(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
