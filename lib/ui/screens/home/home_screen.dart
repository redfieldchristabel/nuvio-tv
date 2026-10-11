import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../state/home_controller.dart';
import '../../../domain/models/meta.dart';
import '../../components/catalog_row_widget.dart';
import '../../components/hero_carousel.dart';
import '../../components/poster_card.dart';

/// Home screen: hero carousel + continue watching + catalog rows.
///
/// Data comes from [homeControllerProvider]; the screen is a pure
/// composition of widgets and reacts to state changes.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    return state.when(
      loading: () => const _HomeSkeleton(),
      error: (e, _) => _HomeError(message: e.toString()),
      data: (data) => _HomeContent(data: data),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent({required this.data});

  final HomeData data;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final _heroKey = GlobalKey<HeroCarouselState>();

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: HeroCarousel(
            key: _heroKey,
            items: data.heroItems,
          ),
        ),
        if (data.continueWatching.isNotEmpty)
          SliverToBoxAdapter(
            child: CatalogRowWidget(
              title: 'Continue Watching',
              itemCount: data.continueWatching.length,
              itemBuilder: (context, index) {
                final entry = data.continueWatching[index];
                return PosterCard(
                  item: entry.item,
                  progressFraction: entry.fraction,
                );
              },
            ),
          ),
        ...data.catalogRows.map(
          (row) => SliverToBoxAdapter(
            child: CatalogRowWidget(
              title: row.catalogName,
              itemCount: row.items.length,
              itemBuilder: (context, index) {
                final item = row.items[index] as MetaPreview;
                return PosterCard(item: item);
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          color: NuvioColors.accent,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: NuvioColors.textTertiary, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Could not load your home',
            style: TextStyle(
                color: NuvioColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NuvioColors.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
