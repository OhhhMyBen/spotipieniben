import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/lyric_line.dart';
import '../models/song_track.dart';
import '../providers/app_providers.dart';
import '../providers/library_provider.dart';
import '../providers/lyrics_provider.dart';
import '../providers/playback_provider.dart';
import '../theme/app_theme.dart';
import '../utils/duration_formatter.dart';
import '../widgets/artwork_image.dart';
import '../widgets/marquee_text.dart';
import '../widgets/mini_equalizer.dart';
import '../widgets/playlist_dialogs.dart';
import '../widgets/queue_sheet.dart';
import 'lyrics_screen.dart';
import 'settings_screen.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double? _dragValueMs;
  String? _lastTrackPath;

  static const List<double> _speedSteps = [1.0, 1.25, 1.5, 0.75];

  Future<void> _cycleSpeed(double currentSpeed) async {
    final idx = _speedSteps.indexWhere((s) => (s - currentSpeed).abs() < 0.05);
    final nextSpeed = _speedSteps[(idx + 1) % _speedSteps.length];
    await ref.read(audioHandlerProvider).setSpeed(nextSpeed);
  }

  Future<void> _showSleepTimerSheet(BuildContext context) async {
    final active = ref.read(sleepTimerProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sleep Timer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (final mins in [15, 30, 45, 60])
                ListTile(
                  leading: const Icon(
                    Icons.bedtime_outlined,
                    color: AppColors.softLavender,
                  ),
                  title: Text('$mins minutes'),
                  onTap: () {
                    ref
                        .read(sleepTimerProvider.notifier)
                        .setTimer(Duration(minutes: mins));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sleep timer set for $mins minutes'),
                      ),
                    );
                  },
                ),
              if (active != null)
                ListTile(
                  leading: const Icon(
                    Icons.timer_off_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Turn Off Timer',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    ref.read(sleepTimerProvider.notifier).setTimer(null);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentTrackProvider).value;
    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceBase,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No track loaded',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (_lastTrackPath != track.filePath) {
      _lastTrackPath = track.filePath;
      _dragValueMs = null;
    }

    final dominantColor =
        ref.watch(currentTrackDominantColorProvider).value ??
        AppColors.surfaceDeepPlum;
    final sourceLabel = ref.watch(sourceLabelProvider).value ?? 'Local Storage';
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? track.duration;
    final shuffleEnabled = ref.watch(shuffleEnabledProvider).value ?? false;
    final loopMode = ref.watch(loopModeProvider).value ?? LoopMode.off;
    final speed = ref.watch(playbackSpeedProvider).value ?? 1.0;
    final sleepRemaining = ref.watch(sleepTimerProvider);
    final isLiked = ref
        .watch(libraryProvider.select((l) => l.favoritePaths))
        .contains(track.filePath);

    final handler = ref.read(audioHandlerProvider);
    final totalMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs =
        _dragValueMs ?? position.inMilliseconds.toDouble().clamp(0.0, totalMs);
    final displayPosition = Duration(milliseconds: currentMs.round());
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF100D17),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              Color.lerp(AppColors.surfaceDeepPlum, dominantColor, 0.45) ??
                  AppColors.surfaceDeepPlum,
              AppColors.surfaceBase,
              const Color(0xFF100D17),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Dynamic Ambient Radiant Backlights
            Positioned(
              top: -48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryAccent.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final artworkSize = (constraints.maxHeight * 0.33).clamp(
                    210.0,
                    316.0,
                  );

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 4, 20, bottomInset + 14),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - bottomInset - 18)
                            .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1. Top App Bar + Sub-header Source Pill
                          Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 28,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/icon/appicon.jpg',
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Now Playing',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Track options',
                                    onPressed: () => showTrackOptionsSheet(
                                      context,
                                      ref,
                                      track,
                                    ),
                                    icon: const Icon(
                                      Icons.more_vert_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: 'Open Settings',
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const SettingsScreen(),
                                        ),
                                      ),
                                      child: const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Center(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.softLavender,
                                            ),
                                            child: SizedBox(
                                              width: 32,
                                              height: 32,
                                              child: Icon(
                                                Icons.person_rounded,
                                                size: 18,
                                                color: Color(0xFF4C007D),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerHigh
                                            .withValues(alpha: 0.72),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.folder_rounded,
                                            size: 14,
                                            color: AppColors.softLavender,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'PLAYING FROM ${sourceLabel.toUpperCase()}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.1,
                                                color: AppColors.softLavender,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      _CircleActionIcon(
                                        icon: Icons.graphic_eq_rounded,
                                        tooltip: 'Audio specs',
                                        onTap: () =>
                                            showSongInfoSheet(context, track),
                                      ),
                                      const SizedBox(width: 6),
                                      _CircleActionIcon(
                                        icon: Icons.queue_music_rounded,
                                        tooltip: 'Queue',
                                        onTap: () => showQueueSheet(context),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 2. Hero Artwork Stage
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: artworkSize - 12,
                                  height: artworkSize - 12,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: const LinearGradient(
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight,
                                      colors: [
                                        AppColors.badgeContainer,
                                        AppColors.primaryAccent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryAccent
                                            .withValues(alpha: 0.45),
                                        blurRadius: 40,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                Stack(
                                  children: [
                                    ArtworkImage(
                                      track: track,
                                      size: artworkSize,
                                      borderRadius: 22,
                                      cacheSize: 700,
                                    ),
                                    // Bottom-left Live Equalizer Pill
                                    Positioned(
                                      left: 12,
                                      bottom: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF100D17)
                                              .withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            MiniEqualizer(
                                              isPlaying: isPlaying,
                                              color: AppColors.softLavender,
                                              height: 12,
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              track.fileExtension == '.flac' ||
                                                      track.fileExtension ==
                                                          '.wav'
                                                  ? 'LOSSLESS LOCAL'
                                                  : '${track.formatBadge} LOCAL',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.9,
                                                color: AppColors.softLavender,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Top-right Fullscreen Lyrics Shortcut
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Semantics(
                                        button: true,
                                        label: 'Open fullscreen lyrics',
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const LyricsScreen(),
                                            ),
                                          ),
                                          child: SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: Center(
                                              child: Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(0xFF100D17)
                                                      .withValues(alpha: 0.8),
                                                ),
                                                child: const Icon(
                                                  Icons.fullscreen_rounded,
                                                  size: 19,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 3. Metadata, Badges, Scrubber & Controls
                          Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        MarqueeText(
                                          text: track.title,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${track.artist} • ${track.album}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Semantics(
                                    button: true,
                                    label: isLiked
                                        ? 'Remove from Liked Songs'
                                        : 'Add to Liked Songs',
                                    child: GestureDetector(
                                      onTap: () => ref
                                          .read(libraryProvider.notifier)
                                          .toggleFavorite(track),
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.surfaceContainerHigh
                                              .withValues(alpha: 0.85),
                                        ),
                                        child: Icon(
                                          isLiked
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: isLiked
                                              ? AppColors.softLavender
                                              : AppColors.textSecondary,
                                          size: 23,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _NowPlayingBadgesRow(track: track),
                              const SizedBox(height: 6),

                              // Scrubber
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4.5,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7.5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 15,
                                  ),
                                  activeTrackColor: AppColors.primaryAccent,
                                  inactiveTrackColor:
                                      AppColors.surfaceContainerHighest,
                                  thumbColor: Colors.white,
                                  overlayColor: AppColors.primaryAccent
                                      .withValues(alpha: 0.25),
                                ),
                                child: Slider(
                                  value: currentMs.clamp(0.0, totalMs),
                                  min: 0.0,
                                  max: totalMs,
                                  onChanged: (val) =>
                                      setState(() => _dragValueMs = val),
                                  onChangeEnd: (val) async {
                                    await handler.seek(
                                      Duration(milliseconds: val.round()),
                                    );
                                    if (mounted) {
                                      setState(() => _dragValueMs = null);
                                    }
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatDuration(displayPosition),
                                      style: AppTheme.tabularTimeStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textOnSurface,
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () => _cycleSpeed(speed),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.speed_rounded,
                                              size: 12,
                                              color: AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${speed}x',
                                              style: AppTheme.tabularTimeStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatRemaining(
                                        displayPosition,
                                        duration,
                                      ),
                                      style: AppTheme.tabularTimeStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Master Console Deck
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _ControlToggleButton(
                                    icon: Icons.shuffle_rounded,
                                    active: shuffleEnabled,
                                    onTap: () => handler.toggleShuffle(),
                                  ),
                                  IconButton(
                                    onPressed: () => handler.skipToPrevious(),
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                      size: 36,
                                      color: AppColors.textOnSurface,
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: isPlaying ? 'Pause' : 'Play',
                                    child: GestureDetector(
                                      onTap: () => isPlaying
                                          ? handler.pause()
                                          : handler.play(),
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.bottomLeft,
                                            end: Alignment.topRight,
                                            colors: [
                                              AppColors.badgeContainer,
                                              AppColors.primaryAccent,
                                              AppColors.softLavender,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryAccent
                                                  .withValues(alpha: 0.55),
                                              blurRadius: 24,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => handler.skipToNext(),
                                    icon: const Icon(
                                      Icons.skip_next_rounded,
                                      size: 36,
                                      color: AppColors.textOnSurface,
                                    ),
                                  ),
                                  _RepeatControlButton(
                                    loopMode: loopMode,
                                    onTap: () => handler.cycleRepeatMode(),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 4. Bottom Lyrics Preview Card + Auxiliary Footer Utility Deck
                          Column(
                            children: [
                              _LyricsPreviewCard(track: track),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => showQueueSheet(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerHigh
                                            .withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.headphones_rounded,
                                            size: 16,
                                            color: AppColors.softLavender,
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            '${track.formatBadge} Local Out',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (sleepRemaining != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Text(
                                            formatDuration(sleepRemaining),
                                            style: AppTheme.tabularTimeStyle(
                                              fontSize: 11,
                                              color: AppColors.softLavender,
                                            ),
                                          ),
                                        ),
                                      _CircleActionIcon(
                                        icon: Icons.bedtime_outlined,
                                        tooltip: 'Sleep timer',
                                        active: sleepRemaining != null,
                                        onTap: () =>
                                            _showSleepTimerSheet(context),
                                      ),
                                      const SizedBox(width: 8),
                                      _CircleActionIcon(
                                        icon: Icons.info_outline_rounded,
                                        tooltip: 'Track details',
                                        onTap: () =>
                                            showSongInfoSheet(context, track),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
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
    );
  }
}

class _CircleActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _CircleActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.primaryAccent.withValues(alpha: 0.25)
                      : AppColors.surfaceContainerHigh.withValues(alpha: 0.65),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: active ? AppColors.softLavender : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingBadgesRow extends ConsumerWidget {
  final SongTrack track;

  const _NowPlayingBadgesRow({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final lyrics = lyricsAsync.value;
    final badge = lyrics != null && !lyrics.isEmpty
        ? lyrics.badgeLabel
        : track.lyricsBadgeLabel;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _SpecPill(label: track.audioSpecLabel.toUpperCase()),
        if (badge != null && badge.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.badgeContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryAccent.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.softLavender,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  badge == 'LRC' ? 'SYNCED LRC' : 'EMBEDDED ID3',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: Color(0xFFF2DAFF),
                  ),
                ),
              ],
            ),
          ),
        _SpecPill(label: formatFileSize(track.sizeBytes)),
      ],
    );
  }
}

class _SpecPill extends StatelessWidget {
  final String label;

  const _SpecPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: AppColors.softLavender,
        ),
      ),
    );
  }
}

class _ControlToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ControlToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: active ? AppColors.softLavender : AppColors.textSecondary,
            size: 23,
          ),
        ),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.softLavender : Colors.transparent,
          ),
        ),
      ],
    );
  }
}

class _RepeatControlButton extends StatelessWidget {
  final LoopMode loopMode;
  final VoidCallback onTap;

  const _RepeatControlButton({required this.loopMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = loopMode != LoopMode.off;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: active ? AppColors.softLavender : AppColors.textSecondary,
            size: 23,
          ),
        ),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.softLavender : Colors.transparent,
          ),
        ),
      ],
    );
  }
}

class _LyricsPreviewCard extends ConsumerWidget {
  final SongTrack track;

  const _LyricsPreviewCard({required this.track});

  void _openFullLyrics(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LyricsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final activeIdx = ref.watch(activeLyricIndexProvider);

    return GestureDetector(
      onTap: () => _openFullLyrics(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE624163B), Color(0xF2181226)],
          ),
          border: Border.all(
            color: AppColors.primaryAccent.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              bottom: -24,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryAccent.withValues(alpha: 0.16),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mic_rounded,
                      size: 16,
                      color: AppColors.softLavender,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Lyrics',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    lyricsAsync.when(
                      data: (data) => data.isEmpty
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data.isSynced ? 'LRC AUTO-SYNC' : 'STATIC ID3',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.softLavender,
                                ),
                              ),
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh.withValues(
                          alpha: 0.85,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Expand',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.open_in_full_rounded,
                            size: 13,
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                lyricsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.softLavender,
                        ),
                      ),
                    ),
                  ),
                  error: (_, _) => const Text(
                    'Unable to load lyrics for this track.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  data: (lyrics) {
                    if (lyrics.isEmpty) {
                      return Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'No lyrics found for this track. Tap to import a .lrc file.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.softLavender,
                              side: const BorderSide(
                                color: AppColors.primaryAccent,
                              ),
                            ),
                            onPressed: () => ref
                                .read(lyricsActionsProvider)
                                .importLrcForTrack(track),
                            child: const Text('Import .LRC'),
                          ),
                        ],
                      );
                    }
                    return _ThreeLineLyricsSnippet(
                      lyrics: lyrics,
                      activeIndex: activeIdx,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreeLineLyricsSnippet extends StatelessWidget {
  final TrackLyrics lyrics;
  final int activeIndex;

  const _ThreeLineLyricsSnippet({
    required this.lyrics,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final lines = lyrics.lines;
    if (!lyrics.isSynced) {
      final snippet = lines.take(3).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: snippet
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    final idx = activeIndex < 0 ? 0 : activeIndex;
    final prevLine = idx > 0 ? lines[idx - 1].text : null;
    final currentLine = lines[idx].text;
    final nextLine = idx + 1 < lines.length ? lines[idx + 1].text : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prevLine != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              prevLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppColors.textSecondary.withValues(alpha: 0.45),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 24,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: AppColors.softLavender,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softLavender.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  currentLine,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                    shadows: [
                      Shadow(
                        color: AppColors.softLavender.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (nextLine != null)
          Text(
            nextLine,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppColors.softLavender.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}
