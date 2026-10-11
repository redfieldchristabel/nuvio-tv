import 'dart:async';
import 'package:collection/collection.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';
import 'package:nuvio_tv_flutter/domain/models/addon.dart';
import 'package:nuvio_tv_flutter/domain/models/catalog_row.dart';
import 'package:nuvio_tv_flutter/domain/models/meta.dart';
import 'package:nuvio_tv_flutter/domain/models/stream.dart';
import 'package:nuvio_tv_flutter/domain/models/watch_progress.dart';
import 'package:nuvio_tv_flutter/domain/repositories/stream_logic.dart';

import '../remote/addon_api.dart';

/// Resolves streams for a movie/episode from all installed addons.
///
/// Merges results across addons, tags each with its origin, dedupes,
/// and orders by addon priority. Plugin/debrid legs plug in later.
class StreamRepository {
  StreamRepository({AddonApi? api, HttpClient? http})
      : _api = api ?? AddonApi(http ?? HttpClient());

  final AddonApi _api;

  /// Resolve streams across all enabled stream-capable addons.
  Future<Result<List<Stream>>> resolve(
    StreamRequest request,
    List<Addon> addons,
  ) async {
    final capable = addons
        .where((a) => a.enabled && a.supportsResource('stream'))
        .toList();
    if (capable.isEmpty) {
      return Result.ok(const []);
    }

    final videoId = request.videoId ?? request.contentId;
    final results = await Future.wait(capable.map((addon) async {
      final uri = Uri.tryParse(addon.url);
      if (uri == null) return <Stream>[];
      final result = await _api.getStreams(uri, request.type.wireName, videoId);
      return switch (result) {
        Ok(:final value) => value
            .map((s) => s.copyWith(
                  addonId: addon.id,
                  addonName: s.addonName ?? addon.name,
                  addonLogo: s.addonLogo ?? addon.logo,
                  addonBaseUrl: addon.url,
                  addonOrderIndex: addon.orderIndex,
                ))
            .toList(),
        Err() => <Stream>[],
      };
    }));

    final merged = results.expand((r) => r).toList();
    final deduped = _dedupe(merged);
    return Result.ok(StreamOrdering.order(deduped));
  }

  /// Dedupe by (url | infoHash+fileIdx | ytId) signature.
  List<Stream> _dedupe(List<Stream> streams) {
    final seen = <String>{};
    final out = <Stream>[];
    for (final s in streams) {
      final sig = s.isTorrent
          ? 'torrent:${s.infoHash}:${s.fileIdx ?? ''}'
          : s.isYoutube
              ? 'yt:${s.ytId}'
              : 'url:${s.url}';
      if (seen.add(sig)) out.add(s);
    }
    return out;
  }
}

/// Fetches meta details with addon fallback: first addon that answers wins.
class MetaRepository {
  MetaRepository({AddonApi? api, HttpClient? http})
      : _api = api ?? AddonApi(http ?? HttpClient());

  final AddonApi _api;

  Future<Result<Meta>> getDetail(
    String type,
    String id,
    List<Addon> addons,
  ) async {
    final capable = addons
        .where((a) => a.enabled && a.supportsResource('meta'))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    AppError? lastError;
    for (final addon in capable) {
      final uri = Uri.tryParse(addon.url);
      if (uri == null) continue;
      final result = await _api.getMeta(uri, type, id);
      if (result.isOk) return result;
      lastError = result.errorOrNull;
    }
    return Result.err(
        lastError ?? AppError.notFound('No addon provides meta for $id'));
  }
}

/// Fetches catalog rows across addons for the home screen.
class CatalogRepository {
  CatalogRepository({AddonApi? api, HttpClient? http})
      : _api = api ?? AddonApi(http ?? HttpClient());

  final AddonApi _api;

  /// Build the home row plan from enabled addons' catalogs.
  List<CatalogRow> planRows(List<Addon> addons) {
    final rows = <CatalogRow>[];
    final enabled =
        addons.where((a) => a.enabled && a.supportsResource('catalog')).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    for (final addon in enabled) {
      for (final catalog in addon.catalogs) {
        final type = catalog.type ?? addon.types.firstOrNull ?? 'movie';
        rows.add(CatalogRow(
          addonId: addon.id,
          addonName: addon.name,
          type: type,
          catalogId: catalog.id,
          catalogName: catalog.name ?? catalog.id,
          addonOrderIndex: addon.orderIndex,
          isLoading: true,
        ));
      }
    }
    return rows;
  }

  /// Fetch items for one row. Supports genre + pagination via extra.
  Future<Result<CatalogRow>> fetchRow(
    CatalogRow row,
    List<Addon> addons, {
    Map<String, String> extra = const {},
  }) async {
    final addon = addons.where((a) => a.id == row.addonId).firstOrNull;
    if (addon == null) {
      return Result.err(AppError.notFound('Addon ${row.addonId} gone'));
    }
    final uri = Uri.tryParse(addon.url);
    if (uri == null) {
      return Result.err(AppError.parse('Bad addon URL'));
    }
    final result = await _api.getCatalog(
      uri,
      type: row.type,
      catalogId: row.catalogId,
      extra: extra,
    );
    return switch (result) {
      Ok(:final value) => Result.ok(row.copyWith(items: value, isLoading: false)),
      Err(:final error) => Result.err(error),
    };
  }
}

/// Watch progress persistence (continue-watching state).
class WatchProgressStore {
  WatchProgressStore(this._store);

  final LocalStore _store;
  static const _key = StorageKeys.watchProgress;

  Future<List<WatchProgress>> getAll() async {
    final raw = _store.getString(_key);
    final decoded = StoreJson.decode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WatchProgress.fromJson)
        .toList();
  }

  Future<void> upsert(WatchProgress progress) async {
    final all = await getAll();
    final key = _itemKey(progress.contentId, progress.videoId);
    all.removeWhere(
        (p) => _itemKey(p.contentId, p.videoId) == key);
    all.add(progress);
    await _save(all);
  }

  Future<void> remove(String contentId, {String? videoId}) async {
    final all = await getAll();
    final key = _itemKey(contentId, videoId);
    all.removeWhere((p) => _itemKey(p.contentId, p.videoId) == key);
    await _save(all);
  }

  Future<WatchProgress?> get(String contentId, {String? videoId}) async {
    final all = await getAll();
    final key = _itemKey(contentId, videoId);
    for (final p in all) {
      if (_itemKey(p.contentId, p.videoId) == key) return p;
    }
    return null;
  }

  String _itemKey(String contentId, String? videoId) =>
      videoId == null ? contentId : '$contentId|$videoId';

  Future<void> _save(List<WatchProgress> progress) async {
    await _store.setString(
        _key, StoreJson.encode(progress.map((p) => p.toJson()).toList()));
  }
}

/// Watched-items persistence (series episode markers).
class WatchedItemsStore {
  WatchedItemsStore(this._store);

  final LocalStore _store;
  static const _key = StorageKeys.watchedItems;

  Future<Map<String, WatchedItem>> getAll() async {
    final raw = _store.getString(_key);
    final decoded = StoreJson.decode(raw);
    if (decoded is! List) return {};
    final out = <String, WatchedItem>{};
    for (final entry in decoded.whereType<Map<String, dynamic>>()) {
      final item = WatchedItem.fromJson(entry);
      out[item.contentId] = item;
    }
    return out;
  }

  Future<void> markWatched(String contentId, String contentType,
      {String? videoId}) async {
    final all = await getAll();
    final existing = all[contentId];
    final episodes = existing?.watchedEpisodes.toSet() ?? <String>{};
    if (videoId != null) episodes.add(videoId);
    all[contentId] = WatchedItem(
      contentId: contentId,
      contentType: contentType,
      watchedAt: DateTime.now(),
      watchedEpisodes: episodes,
    );
    await _save(all);
  }

  Future<void> markUnwatched(String contentId, {String? videoId}) async {
    final all = await getAll();
    if (videoId == null) {
      all.remove(contentId);
    } else {
      final existing = all[contentId];
      if (existing != null) {
        final episodes = existing.watchedEpisodes.toSet()..remove(videoId);
        all[contentId] = WatchedItem(
          contentId: contentId,
          contentType: existing.contentType,
          watchedAt: existing.watchedAt,
          watchedEpisodes: episodes,
        );
      }
    }
    await _save(all);
  }

  Future<bool> isWatched(String contentId, {String? videoId}) async {
    final all = await getAll();
    final item = all[contentId];
    if (item == null) return false;
    if (videoId == null) return true;
    return item.watchedEpisodes.contains(videoId);
  }

  Future<void> _save(Map<String, WatchedItem> items) async {
    await _store.setString(
        _key, StoreJson.encode(items.values.map((i) => i.toJson()).toList()));
  }
}
