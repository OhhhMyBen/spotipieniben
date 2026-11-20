import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MiniEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;

  const MiniEqualizer({
    super.key,
    required this.isPlaying,
    this.color = AppColors.primaryAccent,
    this.height = 16,
  });

  @override
  State<MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<MiniEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant MiniEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.isPlaying ? _controller.value : 0.3;
        final h1 = widget.height * (0.35 + 0.65 * t);
        final h2 = widget.height * (0.35 + 0.65 * (1 - t));
        final h3 = widget.height * (0.3 + 0.7 * ((t + 0.5) % 1.0));
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(h1),
              const SizedBox(width: 2.5),
              _bar(h2),
              const SizedBox(width: 2.5),
              _bar(h3),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double h) {
    return Container(
      width: 3,
      height: h,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
