import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/catalog_repository_impl.dart';
import '../../data/repositories/addon_repository_impl.dart';
import '../../domain/models/addon.dart';
import '../../domain/models/catalog_row.dart';
import '../../domain/models/meta.dart';
import '../../domain/models/content_type.dart';
import '../../domain/repositories/stream_logic.dart';

/// Data bundle the home screen renders.
class HomeData {
  const HomeData({
    required this.heroItems,
    required this.continueWatching,
    required this.catalogRows,
  });

  final List<MetaPreview> heroItems;
  final List<ContinueWatchingEntry> continueWatching;
  final List<CatalogRow> catalogRows;
}

/// One entry in the continue-watching row.
class ContinueWatchingEntry {
  const ContinueWatchingEntry({
    required this.item,
    required this.fraction,
    this.videoId,
  });

  final MetaPreview item;
  final double fraction;
  final String? videoId;
}

/// Async home data: hero items + continue watching + catalog rows.
class HomeController extends AsyncNotifier<HomeData> {
  @override
  Future<HomeData> build() async {
    // Dependencies: addons + progress stores come from providers.
    final addons = await ref.watch(addonsProvider.future);
    final catalogRepo = ref.watch(catalogRepositoryProvider);
    final progressStore = ref.watch(watchProgressStoreProvider);

    // Plan rows from addon catalogs.
    final rows = catalogRepo.planRows(addons);

    // Fetch all rows concurrently; failures produce empty rows (never block
    // the whole home on one bad addon).
    final fetched = await Future.wait(rows.map((row) async {
      final result = await catalogRepo.fetchRow(row, addons);
      return result.valueOrNull ?? row.copyWith(items: const [], isLoading: false);
    }));

    // Continue watching from progress store.
    final allProgress = await progressStore.getAll();
    final window = ContinueWatchingPolicy.renderWindow(allProgress);

    // Hero: first items of the first non-empty rows.
    final heroItems = <MetaPreview>[];
    for (final row in fetched) {
      for (final item in row.items) {
        if (heroItems.length >= 5) break;
        if (item is MetaPreview && item.background != null) {
          heroItems.add(item);
        }
      }
      if (heroItems.length >= 5) break;
    }

    // Enrich continue-watching entries with meta previews (poster lookup
    // from the catalog rows we already have).
    final byId = <String, MetaPreview>{};
    for (final row in fetched) {
      for (final item in row.items) {
        if (item is MetaPreview) byId[item.id] = item;
      }
    }
    final cwEntries = window.map((p) {
      final item = byId[p.contentId] ??
          MetaPreview(id: p.contentId, type: ContentType.fromString(p.contentType));
      return ContinueWatchingEntry(
        item: item,
        fraction: p.fraction,
        videoId: p.videoId,
      );
    }).toList();

    return HomeData(
      heroItems: heroItems,
      continueWatching: cwEntries,
      catalogRows: fetched.where((r) => r.items.isNotEmpty).toList(),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Providers wiring. Kept in this file (state layer) so screens import one
/// thing and tests can override any of them.
final addonsProvider =
    AsyncNotifierProvider<AddonsController, List<Addon>>(
        AddonsController.new);

class AddonsController extends AsyncNotifier<List<Addon>> {
  @override
  Future<List<Addon>> build() async {
    final repo = ref.watch(addonRepositoryProvider);
    return repo.getAddons();
  }
}

final addonRepositoryProvider = Provider<AddonRepository>((ref) {
  throw UnimplementedError('Override in bootstrap with real repository');
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository();
});

final watchProgressStoreProvider = Provider<WatchProgressStore>((ref) {
  throw UnimplementedError('Override in bootstrap with real store');
});

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeData>(HomeController.new);
