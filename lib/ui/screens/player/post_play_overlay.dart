import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/models/meta.dart';
import '../../components/poster_card.dart';

/// Post-play overlay: shown when playback ends (or nears the end).
///
/// Port of the official post-play experience: recommendations row +
/// countdown to next episode (series) + replay/close actions.
///
/// Show conditions (from postPlayRecommendationController.js):
/// - playback ended, OR
/// - movie: position >= trigger (default ~98% of duration), OR
/// - series: next-episode threshold reached
class PostPlayOverlay extends StatefulWidget {
  const PostPlayOverlay({
    super.key,
    required this.recommendations,
    required this.title,
    this.nextEpisodeLabel,
    this.countdownSeconds,
    this.onPlayNext,
    this.onReplay,
    this.onClose,
    this.onSelectRecommendation,
  });

  final String title;
  final List<MetaPreview> recommendations;

  /// Series: "S2:E5 · Episode Name" for the next episode.
  final String? nextEpisodeLabel;

  /// Series auto-play countdown (5..1); null = no auto-advance.
  final int? countdownSeconds;

  final VoidCallback? onPlayNext;
  final VoidCallback? onReplay;
  final VoidCallback? onClose;
  final ValueChanged<MetaPreview>? onSelectRecommendation;

  @override
  State<PostPlayOverlay> createState() => _PostPlayOverlayState();
}

class _PostPlayOverlayState extends State<PostPlayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420), // official transition
    );
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: NuvioColors.bg.withValues(alpha: 0.97),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: NuvioSpacing.safeGutterWide),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nextEpisodeLabel != null
                        ? 'Up next'
                        : 'You finished watching',
                    style: const TextStyle(
                        color: NuvioColors.textTertiary, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          widget.nextEpisodeLabel ?? widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: NuvioColors.text,
                              fontSize: 30,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (widget.countdownSeconds != null) ...[
                        const SizedBox(width: 14),
                        _CountdownRing(seconds: widget.countdownSeconds!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (widget.nextEpisodeLabel != null)
                        _PostPlayButton(
                          label: 'Play now',
                          icon: Icons.play_arrow,
                          primary: true,
                          onTap: widget.onPlayNext ?? () {},
                        ),
                      if (widget.nextEpisodeLabel != null)
                        const SizedBox(width: 14),
                      _PostPlayButton(
                        label: 'Watch again',
                        icon: Icons.replay,
                        onTap: widget.onReplay ?? () {},
                      ),
                      const SizedBox(width: 14),
                      _PostPlayButton(
                        label: 'Close',
                        icon: Icons.close,
                        onTap: widget.onClose ?? () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (widget.recommendations.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(
                    left: NuvioSpacing.safeGutterWide, bottom: 10),
                child: const Text(
                  'More like this',
                  style: TextStyle(
                      color: NuvioColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                height: NuvioSpacing.posterHeight + 24,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: NuvioSpacing.safeGutterWide),
                  itemExtent: NuvioSpacing.posterWidth +
                      NuvioSpacing.cardGap,
                  itemCount: widget.recommendations.length,
                  itemBuilder: (context, index) {
                    final item = widget.recommendations[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: NuvioSpacing.cardGap),
                      child: PosterCard(
                        item: item,
                        onSelected: () =>
                            widget.onSelectRecommendation?.call(item),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: NuvioSpacing.safeGutter),
          ],
        ),
      ),
    );
  }
}

/// Circular countdown next to the next-episode title.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: NuvioColors.accent, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        '$seconds',
        style: const TextStyle(
            color: NuvioColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PostPlayButton extends StatefulWidget {
  const _PostPlayButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_PostPlayButton> createState() => _PostPlayButtonState();
}

class _PostPlayButtonState extends State<_PostPlayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.primary,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: NuvioSpacing.buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: _focused
                ? (widget.primary ? NuvioColors.text : NuvioColors.cardFocused)
                : (widget.primary ? NuvioColors.text : NuvioColors.card),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 26,
                  color: _focused || widget.primary
                      ? NuvioColors.bg
                      : NuvioColors.text),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: _focused || widget.primary
                      ? NuvioColors.bg
                      : NuvioColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pure logic ported from the official controller: when to show post-play.
class PostPlayPolicy {
  const PostPlayPolicy._();

  static const prefetchProgress = 0.9;
  static const trailerCountdownSeconds = 5;
  static const finalCountdownSeconds = 5;
  static const defaultMovieThresholdPercent = 98.0;

  /// Whether the post-play overlay should appear.
  static bool shouldShow({
    required bool isSeries,
    required Duration position,
    required Duration duration,
    bool playbackEnded = false,
    bool seriesThresholdReached = false,
    double movieThresholdPercent = defaultMovieThresholdPercent,
  }) {
    if (playbackEnded) return true;
    if (duration <= Duration.zero) return false;
    if (isSeries) return seriesThresholdReached;
    final fraction = position.inMilliseconds / duration.inMilliseconds;
    return fraction * 100 >= movieThresholdPercent;
  }

  /// Countdown to auto-advance (5..1) in the final seconds, else null.
  static int? countdownSeconds(Duration position, Duration duration) {
    if (duration <= Duration.zero) return null;
    final remaining =
        duration.inSeconds - position.inSeconds;
    if (remaining > finalCountdownSeconds) return null;
    return remaining.clamp(1, finalCountdownSeconds);
  }

  /// Prefetch recommendations at 90% or 10 minutes remaining.
  static bool shouldPrefetch({
    required Duration position,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) return false;
    final fraction = position.inMilliseconds / duration.inMilliseconds;
    final remainingMs = duration.inMilliseconds - position.inMilliseconds;
    return fraction >= prefetchProgress || remainingMs <= 10 * 60 * 1000;
  }
}
