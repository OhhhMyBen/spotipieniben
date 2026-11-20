import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocityPxPerSec;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocityPxPerSec = 34,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoop());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  Future<void> _startLoop() async {
    while (!_disposed && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (_disposed || !mounted || !_scrollController.hasClients) continue;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 2) continue;

      final durationMs = ((maxExtent / widget.velocityPxPerSec) * 1000)
          .round()
          .clamp(1200, 14000);
      await _scrollController.animateTo(
        maxExtent,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.linear,
      );
      if (_disposed || !mounted) break;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (_disposed || !mounted || !_scrollController.hasClients) continue;
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
