import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/lyric_line.dart';
import '../models/song_track.dart';
import '../providers/app_providers.dart';
import '../providers/lyrics_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/duration_formatter.dart';
import '../widgets/artwork_image.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  bool _userScrolling = false;
  Timer? _resumeAutoScrollTimer;
  double? _dragValueMs;

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyForLine(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToActiveLine(int index, {bool force = false}) {
    if (index < 0) return;
    if (_userScrolling && !force) return;

    final autoScrollEnabled = ref.read(settingsProvider).autoScrollLyrics;
    if (!autoScrollEnabled && !force) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _lineKeys[index]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.36,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onUserScrollNotification(UserScrollNotification notification) {
    if (notification.direction != ScrollDirection.idle) {
      if (!_userScrolling) {
        setState(() => _userScrolling = true);
      }
      _resumeAutoScrollTimer?.cancel();
      _resumeAutoScrollTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _userScrolling = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentTrackProvider).value;
    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.lyricsFullBackdrop,
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'No track playing',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final activeIdx = ref.watch(activeLyricIndexProvider);
    final offsetMs = ref.watch(lyricsOffsetMsProvider);
    final forceStatic = ref.watch(forceStaticLyricsProvider);
    final fontSize =
        ref.watch(settingsProvider.select((s) => s.lyricFontSize));
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? track.duration;
    final shuffleEnabled = ref.watch(shuffleEnabledProvider).value ?? false;
    final handler = ref.read(audioHandlerProvider);

    ref.listen<int>(activeLyricIndexProvider, (prev, next) {
      if (prev != next && next >= 0 && !forceStatic) {
        _scrollToActiveLine(next);
      }
    });

    final totalMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs = _dragValueMs ??
        position.inMilliseconds.toDouble().clamp(0.0, totalMs);
    final displayPosition = Duration(milliseconds: currentMs.round());

    return Scaffold(
      backgroundColor: AppColors.lyricsFullBackdrop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred Album Art Backdrop Overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.22,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: ArtworkImage(
                  track: track,
                  size: MediaQuery.sizeOf(context).height,
                  borderRadius: 0,
                  cacheSize: 300,
                ),
              ),
            ),
          ),
          // Deep Violet Scrim (#240046)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.lyricsFullBackdrop.withValues(alpha: 0.88),
                    AppColors.lyricsFullBackdrop.withValues(alpha: 0.78),
                    AppColors.backgroundPrimary.withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Compact Top Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  child: Row(
                    children: [
                      ArtworkImage(
                        track: track,
                        size: 40,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${track.artist} • ${track.formatBadge}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.softLavender,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Import .LRC file',
                        onPressed: () async {
                          final ok = await ref
                              .read(lyricsActionsProvider)
                              .importLrcForTrack(track);
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Imported .LRC lyrics file'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.file_upload_outlined,
                          color: AppColors.softLavender,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Collapse',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Synced vs Static Toggle + Time Offset Pill Strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundPrimary
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModeChip(
                              label: 'Synced LRC',
                              selected: !forceStatic,
                              onTap: () => ref
                                  .read(forceStaticLyricsProvider.notifier)
                                  .setForceStatic(false),
                            ),
                            _ModeChip(
                              label: 'Static ID3',
                              selected: forceStatic,
                              onTap: () => ref
                                  .read(forceStaticLyricsProvider.notifier)
                                  .setForceStatic(true),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundPrimary
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => ref
                                  .read(lyricsOffsetMsProvider.notifier)
                                  .nudge(-500),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.fast_rewind_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${offsetMs > 0 ? '+' : ''}${(offsetMs / 1000).toStringAsFixed(1)}s',
                                style: AppTheme.tabularTimeStyle(
                                  fontSize: 11.5,
                                  color: AppColors.softLavender,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => ref
                                  .read(lyricsOffsetMsProvider.notifier)
                                  .nudge(500),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.fast_forward_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Lyric Feed
                Expanded(
                  child: lyricsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        'Failed to read lyrics: $err',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    data: (lyrics) {
                      if (lyrics.isEmpty) {
                        return _EmptyLyricsFallback(
                          track: track,
                          onImport: () async {
                            final ok = await ref
                                .read(lyricsActionsProvider)
                                .importLrcForTrack(track);
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Loaded custom .LRC file'),
                                ),
                              );
                            }
                          },
                        );
                      }

                      final effectiveSynced = lyrics.isSynced && !forceStatic;

                      return Stack(
                        children: [
                          NotificationListener<UserScrollNotification>(
                            onNotification: (notification) {
                              if (effectiveSynced) {
                                _onUserScrollNotification(notification);
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                28,
                                22,
                                180,
                              ),
                              itemCount: lyrics.lines.length,
                              itemBuilder: (context, index) {
                                final line = lyrics.lines[index];
                                final isPast = effectiveSynced &&
                                    activeIdx >= 0 &&
                                    index < activeIdx;
                                final isCurrent =
                                    effectiveSynced && index == activeIdx;

                                return _LyricRowItem(
                                  key: _keyForLine(index),
                                  line: line,
                                  isSyncedMode: effectiveSynced,
                                  isPast: isPast,
                                  isCurrent: isCurrent,
                                  fontSize: fontSize,
                                  onTap: line.timestamp != null
                                      ? () {
                                          setState(() => _userScrolling = false);
                                          final targetMs =
                                              line.timestamp!.inMilliseconds -
                                                  offsetMs;
                                          handler.seek(
                                            Duration(
                                              milliseconds:
                                                  targetMs < 0 ? 0 : targetMs,
                                            ),
                                          );
                                        }
                                      : null,
                                );
                              },
                            ),
                          ),
                          // Floating "Sync" pill when user manually scrolls
                          if (effectiveSynced &&
                              _userScrolling &&
                              activeIdx >= 0)
                            Positioned(
                              right: 20,
                              bottom: 16,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                onPressed: () {
                                  _resumeAutoScrollTimer?.cancel();
                                  setState(() => _userScrolling = false);
                                  _scrollToActiveLine(activeIdx, force: true);
                                },
                                icon: const Icon(
                                  Icons.my_location_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Sync',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // Bottom Floating Glassmorphic Player Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.primaryAccent
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                activeTrackColor: AppColors.primaryAccent,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.14),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: currentMs.clamp(0.0, totalMs),
                                min: 0.0,
                                max: totalMs,
                                onChanged: (val) =>
                                    setState(() => _dragValueMs = val),
                                onChangeEnd: (val) async {
                                  setState(() => _dragValueMs = null);
                                  await handler.seek(
                                    Duration(milliseconds: val.round()),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatDuration(displayPosition),
                                    style: AppTheme.tabularTimeStyle(
                                      fontSize: 11,
                                      color: AppColors.softLavender,
                                    ),
                                  ),
                                  Text(
                                    formatDuration(duration),
                                    style: AppTheme.tabularTimeStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () => handler.toggleShuffle(),
                                  icon: Icon(
                                    Icons.shuffle_rounded,
                                    size: 20,
                                    color: shuffleEnabled
                                        ? AppColors.primaryAccent
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => handler.skipToPrevious(),
                                  icon: const Icon(
                                    Icons.skip_previous_rounded,
                                    size: 28,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => isPlaying
                                      ? handler.pause()
                                      : handler.play(),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryAccent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryAccent
                                              .withValues(alpha: 0.55),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => handler.skipToNext(),
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    size: 28,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                // Mode badge / toggle
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () => ref
                                      .read(forceStaticLyricsProvider.notifier)
                                      .setForceStatic(!forceStatic),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.badgeContainer
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.primaryAccent
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      forceStatic ? 'Static ID3' : 'Synced LRC',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.softLavender,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LyricRowItem extends StatelessWidget {
  final LyricLine line;
  final bool isSyncedMode;
  final bool isPast;
  final bool isCurrent;
  final LyricFontSize fontSize;
  final VoidCallback? onTap;

  const _LyricRowItem({
    super.key,
    required this.line,
    required this.isSyncedMode,
    required this.isPast,
    required this.isCurrent,
    required this.fontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (!isSyncedMode) {
      textColor = AppColors.textPrimary.withValues(alpha: 0.9);
    } else if (isCurrent) {
      textColor = AppColors.textPrimary;
    } else if (isPast) {
      textColor = AppColors.textSecondary.withValues(alpha: 0.4);
    } else {
      textColor = AppColors.textUpcomingLyric.withValues(alpha: 0.65);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCurrent ? 14 : 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedScale(
          scale: isCurrent ? 1.03 : 1.0,
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCurrent)
                Container(
                  width: 4,
                  height: 30,
                  margin: const EdgeInsets.only(right: 10, top: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.softLavender.withValues(alpha: 0.85),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              if (line.timestamp != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 5),
                  child: Text(
                    formatDuration(line.timestamp!),
                    style: AppTheme.tabularTimeStyle(
                      fontSize: 10.5,
                      color: isCurrent
                          ? AppColors.softLavender
                          : AppColors.textMuted.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  line.text,
                  style: TextStyle(
                    fontSize: isCurrent
                        ? fontSize.activeSize
                        : fontSize.inactiveSize,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    height: 1.35,
                    color: textColor,
                    shadows: isCurrent
                        ? [
                            Shadow(
                              color: AppColors.textUpcomingLyric
                                  .withValues(alpha: 0.65),
                              blurRadius: 18,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLyricsFallback extends StatelessWidget {
  final SongTrack track;
  final VoidCallback onImport;

  const _EmptyLyricsFallback({
    required this.track,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderPurpleSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lyrics_outlined,
                size: 46,
                color: AppColors.softLavender,
              ),
              const SizedBox(height: 14),
              const Text(
                'No lyrics found for this track',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Place a "${track.title}.lrc" file beside the audio file or import a .lrc file from local storage.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onImport,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text(
                  'Import .LRC File',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
