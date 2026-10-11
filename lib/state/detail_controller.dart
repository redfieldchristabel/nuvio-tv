import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/catalog_repository_impl.dart';
import 'home_controller.dart' show addonsProvider, watchProgressStoreProvider;
import '../domain/models/content_type.dart';
import '../domain/models/meta.dart';
import '../domain/models/stream.dart';
import '../domain/models/video.dart';
import '../domain/models/watch_progress.dart';
import '../domain/repositories/stream_logic.dart';

/// Detail screen state: meta + streams + watched state.
class DetailController extends FamilyAsyncNotifier<DetailData, DetailParams> {
  @override
  Future<DetailData> build(DetailParams params) async {
    final addons = await ref.watch(addonsProvider.future);
    final metaRepo = ref.watch(metaRepositoryProvider);
    final streamRepo = ref.watch(streamRepositoryProvider);
    final progressStore = ref.watch(watchProgressStoreProvider);
    final watchedStore = ref.watch(watchedItemsStoreProvider);

    // Meta detail (addon fallback chain).
    final metaResult = await metaRepo.getDetail(
      params.contentType.wireName,
      params.metaId,
      addons,
    );
    final meta = metaResult.valueOrNull ??
        Meta(id: params.metaId, type: params.contentType);

    // Streams resolve lazily (only when user opens the picker) but we
    // prefetch for autoplay.
    final streamResult = await streamRepo.resolve(
      StreamRequest(
        contentId: params.metaId,
        type: params.contentType,
        videoId: params.videoId,
      ),
      addons,
    );

    // Watched state.
    final watchedItem = await watchedStore.getAll();
    final watchedEpisodes = watchedItem[params.metaId]?.watchedEpisodes ?? {};
    final progress = await progressStore.get(
      params.metaId,
      videoId: params.videoId,
    );

    return DetailData(
      meta: meta,
      streams: streamResult.valueOrNull ?? const [],
      watchedEpisodes: watchedEpisodes,
      progress: progress,
    );
  }

  /// Mark an episode watched/unwatched and refresh state.
  Future<void> toggleWatched(String videoId, {required bool watched}) async {
    final watchedStore = ref.read(watchedItemsStoreProvider);
    if (watched) {
      await watchedStore.markWatched(state.value!.meta.id, 'series',
          videoId: videoId);
    } else {
      await watchedStore.markUnwatched(state.value!.meta.id, videoId: videoId);
    }
    ref.invalidateSelf();
  }

  /// Save playback position for resume.
  Future<void> saveProgress({
    required int positionMs,
    required int durationMs,
    String? videoId,
  }) async {
    final meta = state.value?.meta;
    if (meta == null) return;
    await ref.read(watchProgressStoreProvider).upsert(WatchProgress(
          contentId: meta.id,
          contentType: meta.type.wireName,
          videoId: videoId,
          positionMs: positionMs,
          durationMs: durationMs,
          updatedAt: DateTime.now(),
        ));
  }
}

class DetailParams {
  const DetailParams({
    required this.metaId,
    required this.contentType,
    this.videoId,
  });

  final String metaId;
  final ContentType contentType;
  final String? videoId;

  /// Wire name for API calls.
  String get type => contentType.wireName;

  @override
  bool operator ==(Object other) =>
      other is DetailParams &&
      other.metaId == metaId &&
      other.contentType == contentType &&
      other.videoId == videoId;

  @override
  int get hashCode => Object.hash(metaId, contentType, videoId);
}

class DetailData {
  const DetailData({
    required this.meta,
    required this.streams,
    required this.watchedEpisodes,
    this.progress,
  });

  final Meta meta;
  final List<Stream> streams;
  final Set<String> watchedEpisodes;
  final WatchProgress? progress;

  /// Next unwatched episode (for the Play/Resume button).
  Video? nextUpEpisode() {
    if (!meta.type.isSeries) return null;
    return NextUpResolver.nextUp(
      videos: meta.videos,
      watchedVideoIds: watchedEpisodes,
    );
  }
}

final detailControllerProvider = AsyncNotifierProvider.family<DetailController,
    DetailData, DetailParams>(DetailController.new);

final metaRepositoryProvider = Provider<MetaRepository>((ref) {
  return MetaRepository();
});

final streamRepositoryProvider = Provider<StreamRepository>((ref) {
  return StreamRepository();
});

final watchedItemsStoreProvider = Provider<WatchedItemsStore>((ref) {
  throw UnimplementedError('Override in bootstrap');
});
