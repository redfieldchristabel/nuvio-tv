import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../domain/models/meta.dart';

/// Hero carousel for the top of the home screen.
///
/// Crossfades backdrop + logo/title on focus change (GPU-only opacity),
/// auto-advances every [autoAdvance] unless paused (focus inside list).
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    required this.items,
    this.autoAdvance = const Duration(seconds: 8),
    this.onSelected,
    this.height = 420,
  });

  final List<MetaPreview> items;
  final Duration autoAdvance;
  final ValueChanged<MetaPreview>? onSelected;
  final double height;

  @override
  State<HeroCarousel> createState() => HeroCarouselState();
}

class HeroCarouselState extends State<HeroCarousel> {
  int _index = 0;
  Timer? _timer;

  MetaPreview get current =>
      widget.items[_index.clamp(0, widget.items.length - 1)];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      setState(() => _index = 0);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(widget.autoAdvance, (_) {
        if (mounted) {
          setState(() => _index = (_index + 1) % widget.items.length);
        }
      });
    }
  }

  /// External focus integration: pause auto-advance while a row has focus.
  void pause() => _timer?.cancel();

  void resume() => _startTimer();

  void next() {
    if (widget.items.isEmpty) return;
    setState(() => _index = (_index + 1) % widget.items.length);
  }

  void previous() {
    if (widget.items.isEmpty) return;
    setState(
        () => _index = (_index - 1 + widget.items.length) % widget.items.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SizedBox(height: widget.height, width: double.infinity);
    }
    final item = current;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop crossfade
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: item.background != null
                ? Image.network(
                    key: ValueKey(item.background),
                    item.background!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: NuvioColors.bgElevated),
                  )
                : Container(color: NuvioColors.bgElevated),
          ),
          // Bottom gradient for text legibility
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1.0],
                colors: [Colors.transparent, NuvioColors.bg],
              ),
            ),
            child: SizedBox.expand(),
          ),
          // Title + meta
          Positioned(
            left: NuvioSpacing.safeGutterWide,
            bottom: 48,
            right: NuvioSpacing.safeGutterWide,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Column(
                key: ValueKey(item.id),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name ?? '',
                    style: const TextStyle(
                      color: NuvioColors.text,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(blurRadius: 12, color: Colors.black54)
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.releaseInfo != null)
                        _metaChip(item.releaseInfo!),
                      if (item.imdbRating != null) ...[
                        const SizedBox(width: 10),
                        _metaChip('★ ${item.imdbRating}'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: NuvioColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
