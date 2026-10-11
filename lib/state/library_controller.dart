import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/library_item.dart';
import '../domain/models/content_type.dart';
import 'home_controller.dart' show watchProgressStoreProvider;
import 'detail_controller.dart' show watchedItemsStoreProvider;

/// Library state: saved + watched lists assembled from stores.
class LibraryController extends AsyncNotifier<LibraryData> {
  @override
  Future<LibraryData> build() async {
    final progressStore = ref.watch(watchProgressStoreProvider);
    final watchedStore = ref.watch(watchedItemsStoreProvider);

    final allProgress = await progressStore.getAll();
    final watchedMap = await watchedStore.getAll();

    // Watched tab: items with a watched marker, most recent first.
    final watched = watchedMap.values
        .map((w) => LibraryItem(
              contentId: w.contentId,
              contentType:
                  ContentType.fromString(w.contentType),
              addedAt: w.watchedAt,
            ))
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    // Saved tab: items with meaningful progress (in-progress or completed),
    // most recent first.
    final saved = allProgress
        .map((p) => LibraryItem(
              contentId: p.contentId,
              contentType: ContentType.fromString(p.contentType),
              addedAt: p.updatedAt,
              progressFraction: p.fraction > 0 ? p.fraction : null,
            ))
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return LibraryData(saved: saved, watched: watched);
  }

  Future<void> removeFromSaved(String contentId) async {
    await ref.read(watchProgressStoreProvider).remove(contentId);
    ref.invalidateSelf();
  }
}

class LibraryData {
  const LibraryData({required this.saved, required this.watched});

  final List<LibraryItem> saved;
  final List<LibraryItem> watched;
}

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, LibraryData>(
        LibraryController.new);
