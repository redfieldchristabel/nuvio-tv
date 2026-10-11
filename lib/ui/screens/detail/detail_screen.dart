import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/models/video.dart';
import '../../components/poster_card.dart';
import '../../components/catalog_row_widget.dart';
import '../../../state/detail_controller.dart';

/// Detail screen: hero, description, episodes (series), stream entry.
///
/// Fully D-pad navigable: up/down between sections, select on play opens
/// the stream picker.
class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({super.key, required this.params});

  final DetailParams params;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailControllerProvider(widget.params));
    return Scaffold(
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NuvioColors.accent),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load this title',
            style: TextStyle(color: NuvioColors.textSecondary, fontSize: 16),
          ),
        ),
        data: (data) => _DetailContent(data: data),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.data});

  final DetailData data;

  @override
  Widget build(BuildContext context) {
    final meta = data.meta;
    return CustomScrollView(
      slivers: [
        // Hero backdrop
        SliverToBoxAdapter(
          child: SizedBox(
            height: 380,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (meta.background != null)
                  Image.network(
                    meta.background!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: NuvioColors.bgElevated),
                  )
                else
                  Container(color: NuvioColors.bgElevated),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.4, 1.0],
                      colors: [Colors.transparent, NuvioColors.bg],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                Positioned(
                  left: NuvioSpacing.safeGutterWide,
                  bottom: 32,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.name ?? '',
                        style: const TextStyle(
                          color: NuvioColors.text,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (meta.releaseInfo != null)
                            _chip(meta.releaseInfo!),
                          if (meta.imdbRating != null) ...[
                            const SizedBox(width: 8),
                            _chip('★ ${meta.imdbRating}'),
                          ],
                          if (meta.runtime != null) ...[
                            const SizedBox(width: 8),
                            _chip(meta.runtime!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Play button + description
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: NuvioSpacing.safeGutterWide, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlayButton(data: data),
                const SizedBox(height: 16),
                if (meta.description != null)
                  Text(
                    meta.description!,
                    style: const TextStyle(
                        color: NuvioColors.textSecondary, fontSize: 15,
                        height: 1.5),
                  ),
                if (meta.genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: meta.genres
                        .map((g) => Chip(
                              label: Text(g,
                                  style: const TextStyle(
                                      color: NuvioColors.textSecondary,
                                      fontSize: 12)),
                              backgroundColor: NuvioColors.card,
                              side: const BorderSide(
                                  color: NuvioColors.border),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Episodes (series only)
        if (meta.type.isSeries && meta.videos.isNotEmpty)
          _EpisodesSection(data: data),
        // More Like This row
        if (data.moreLikeThis.isNotEmpty)
          SliverToBoxAdapter(
            child: CatalogRowWidget(
              title: 'More Like This',
              itemCount: data.moreLikeThis.length,
              itemBuilder: (context, index) =>
                  PosterCard(item: data.moreLikeThis[index]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: NuvioColors.text, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.data});

  final DetailData data;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final nextUp = widget.data.nextUpEpisode();
    final label = nextUp != null
        ? 'Play S${nextUp.season}:E${nextUp.episode}'
        : 'Play';
    return Focus(
      autofocus: true,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          _openStreamPicker();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _openStreamPicker,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: NuvioSpacing.buttonHeight,
          padding: const EdgeInsets.symmetric(
              horizontal: NuvioSpacing.buttonHeight),
          decoration: BoxDecoration(
            color: _focused ? NuvioColors.text : NuvioColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow,
                  size: 30,
                  color: _focused ? NuvioColors.bg : NuvioColors.text),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: _focused ? NuvioColors.bg : NuvioColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStreamPicker() {
    // Stream picker screen lands in INC-4; for now show the streams count.
    final count = widget.data.streams.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$count streams found — picker lands next increment'),
    ));
  }
}

class _EpisodesSection extends StatelessWidget {
  const _EpisodesSection({required this.data});

  final DetailData data;

  @override
  Widget build(BuildContext context) {
    final videos = List.of(data.meta.videos)
      ..sort((a, b) {
        final s = (a.season ?? 0).compareTo(b.season ?? 0);
        if (s != 0) return s;
        return (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: NuvioSpacing.safeGutterWide),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Episodes',
              style: TextStyle(
                  color: NuvioColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...videos.map((v) => _EpisodeTile(
                  video: v,
                  watched: data.watchedEpisodes.contains(v.id),
                )),
          ],
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.video, required this.watched});

  final Video video;
  final bool watched;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NuvioColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: video.thumbnail != null
                ? Image.network(
                    video.thumbnail!,
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                        width: 140,
                        height: 80,
                        color: NuvioColors.bgElevated),
                  )
                : Container(width: 140, height: 80,
                    color: NuvioColors.bgElevated),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'S${video.season ?? 1}:E${video.episode ?? 1} · ${video.title ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: NuvioColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                if (video.overview != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    video.overview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: NuvioColors.textTertiary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (watched)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(Icons.check_circle,
                  color: NuvioColors.accent, size: 22),
            ),
        ],
      ),
    );
  }
}
