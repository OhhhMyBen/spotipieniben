import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_track.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class ArtworkImage extends ConsumerStatefulWidget {
  final SongTrack? track;
  final double size;
  final double borderRadius;
  final int cacheSize;
  final Widget? overlay;

  const ArtworkImage({
    super.key,
    required this.track,
    this.size = 48,
    this.borderRadius = 10,
    this.cacheSize = 300,
    this.overlay,
  });

  @override
  ConsumerState<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends ConsumerState<ArtworkImage> {
  Uint8List? _bytes;
  int? _loadedTrackId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track?.id != widget.track?.id) {
      _load();
    }
  }

  Future<void> _load() async {
    final track = widget.track;
    if (track == null) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    if (_loadedTrackId == track.id && _bytes != null) return;
    _loadedTrackId = track.id;

    final bytes = await ref
        .read(artworkServiceProvider)
        .getArtworkBytes(track, size: widget.cacheSize);
    if (!mounted || widget.track?.id != track.id) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_bytes != null)
              Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              _FallbackArtwork(size: widget.size),
            if (widget.overlay != null) widget.overlay!,
          ],
        ),
      ),
    );
  }
}

class _FallbackArtwork extends StatelessWidget {
  final double size;

  const _FallbackArtwork({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceDeepPlum,
            AppColors.lyricsCardSurface,
            AppColors.surfaceCard,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.softLavender.withValues(alpha: 0.75),
          size: (size * 0.42).clamp(18, 84),
        ),
      ),
    );
  }
}
