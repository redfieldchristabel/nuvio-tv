import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';
import '../../domain/models/meta.dart';

/// A focusable poster card for catalog rows and grids.
///
/// Focus behavior: scales to 1.1 with a white border (GPU-composited only),
/// matching the official card focus treatment. Shows an imdb badge and a
/// progress bar when progress is provided.
class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.item,
    this.width = NuvioSpacing.posterWidth,
    this.height = NuvioSpacing.posterHeight,
    this.progressFraction,
    this.onSelected,
    this.autofocus = false,
  });

  final MetaPreview item;
  final double width;
  final double height;
  final double? progressFraction;
  final VoidCallback? onSelected;
  final bool autofocus;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: _handleKey,
      child: AnimatedScale(
        scale: _focused ? NuvioSpacing.cardFocusScale : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: widget.onSelected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: widget.width,
            height: widget.height,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NuvioSpacing.cardRadius),
              border: _focused
                  ? Border.all(color: NuvioColors.text, width: 3)
                  : null,
            ),
            decoration: BoxDecoration(
              color: NuvioColors.card,
              borderRadius: BorderRadius.circular(NuvioSpacing.cardRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.item.poster != null)
                  Image.network(
                    widget.item.poster!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => _placeholder(),
                    frameBuilder: (context, child, frame, wasSync) {
                      if (wasSync) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 220),
                        child: child,
                      );
                    },
                  )
                else
                  _placeholder(),
                // imdb rating badge
                if (widget.item.imdbRating != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Badge(text: '★ ${widget.item.imdbRating}'),
                  ),
                // progress bar
                if (widget.progressFraction != null &&
                    widget.progressFraction! > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ProgressBar(fraction: widget.progressFraction!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: NuvioColors.card,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        widget.item.name ?? '',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: NuvioColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter)) {
      widget.onSelected?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: NuvioColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      color: NuvioColors.bgElevated,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(color: NuvioColors.progress),
      ),
    );
  }
}
