import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';
import 'package:nuvio_tv_flutter/data/repositories/catalog_repository_impl.dart';
import 'package:nuvio_tv_flutter/domain/models/addon.dart';
import 'package:nuvio_tv_flutter/domain/models/content_type.dart';
import 'package:nuvio_tv_flutter/domain/models/catalog_row.dart';
import 'package:nuvio_tv_flutter/data/remote/addon_api.dart';
import 'package:nuvio_tv_flutter/domain/models/stream.dart';
import 'package:nuvio_tv_flutter/domain/models/watch_progress.dart';
import 'package:nuvio_tv_flutter/domain/repositories/stream_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Addon _addon(String id, String host, {bool enabled = true, int order = 0}) {
  return Addon(
    id: id,
    name: id,
    url: 'https://$host/',
    enabled: enabled,
    orderIndex: order,
    resources: const [AddonResource(name: 'stream'), AddonResource(name: 'meta'), AddonResource(name: 'catalog')],
    catalogs: const [AddonCatalog(id: 'popular', type: 'movie', name: 'Popular')],
    types: const ['movie'],
  );
}

HttpClient _httpFor(Map<String, String> routes) {
  return HttpClient(
    maxRetries: 0,
    client: MockClient((request) async {
      for (final entry in routes.entries) {
        if (request.url.path.contains(entry.key)) {
          return http.Response(entry.value, 200);
        }
      }
      return http.Response('nf', 404);
    }),
  );
}

void main() {
  group('StreamRepository', () {
    test('merges streams from multiple addons with origin tags', () async {
      final httpMock = _httpFor({
        'stream/movie/tt1': '{"streams":[{"name":"A","url":"https://a/1.mp4"}]}',
      });
      final repo = StreamRepository(api: AddonApi(httpMock));
      final addons = [_addon('addon-a', 'a.test', order: 0)];
      final result = await repo.resolve(
        const StreamRequest(contentId: 'tt1', type: ContentType.movie),
        addons,
      );
      final streams = result.valueOrNull!;
      expect(streams.length, 1);
      expect(streams.first.addonId, 'addon-a');
      expect(streams.first.addonOrderIndex, 0);
    });

    test('skips disabled addons and non-stream addons', () async {
      final httpMock = _httpFor({});
      final repo = StreamRepository(api: AddonApi(httpMock));
      final addons = [
        _addon('disabled', 'd.test', enabled: false),
        _addon('nostream', 'n.test'),
      ];
      // remove stream resource from second
      addons[1] = Addon(
        id: 'nostream',
        name: 'nostream',
        url: 'https://n.test/',
        resources: const [AddonResource(name: 'meta')],
      );
      final result = await repo.resolve(
        const StreamRequest(contentId: 'tt1', type: ContentType.movie),
        addons,
      );
      expect(result.valueOrNull, isEmpty);
    });

    test('dedupes identical urls across addons', () async {
      final httpMock = _httpFor({
        'stream/movie/tt1':
            '{"streams":[{"name":"same","url":"https://same/1.mp4"}]}',
      });
      final repo = StreamRepository(api: AddonApi(httpMock));
      final addons = [
        _addon('a', 'a.test', order: 0),
        _addon('b', 'b.test', order: 1),
      ];
      final result = await repo.resolve(
        const StreamRequest(contentId: 'tt1', type: ContentType.movie),
        addons,
      );
      // Both addons return same URL -> deduped to 1.
      expect(result.valueOrNull!.length, 1);
    });

    test('dedupes torrents by infoHash+fileIdx', () async {
      final httpMock = _httpFor({
        'stream/movie/tt1':
            '{"streams":[{"name":"t1","infoHash":"aa","fileIdx":0},{"name":"t2","infoHash":"aa","fileIdx":0},{"name":"t3","infoHash":"aa","fileIdx":1}]}',
      });
      final repo = StreamRepository(api: AddonApi(httpMock));
      final result = await repo.resolve(
        const StreamRequest(contentId: 'tt1', type: ContentType.movie),
        [_addon('a', 'a.test')],
      );
      expect(result.valueOrNull!.length, 2); // (aa,0) and (aa,1)
    });

    test('orders by addon priority', () async {
      final httpMock = HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          if (request.url.host == '1.test') {
            return http.Response(
                '{"streams":[{"name":"x","url":"https://one/1"}]}', 200);
          }
          if (request.url.host == '2.test') {
            return http.Response(
                '{"streams":[{"name":"y","url":"https://two/1"}]}', 200);
          }
          return http.Response('nf', 404);
        }),
      );
      final repo = StreamRepository(api: AddonApi(httpMock));
      final result = await repo.resolve(
        const StreamRequest(contentId: 'tt1', type: ContentType.movie),
        [_addon('first', '1.test', order: 0), _addon('second', '2.test', order: 1)],
      );
      final streams = result.valueOrNull!;
      expect(streams.length, 2);
      expect(streams.first.addonId, 'first');
      expect(streams.last.addonId, 'second');
    });
  });

  group('CatalogRepository', () {
    test('planRows builds rows from enabled catalog addons', () {
      final repo = CatalogRepository();
      final addons = [
        _addon('a', 'a.test', order: 1),
        _addon('b', 'b.test', order: 0, enabled: false),
      ];
      final rows = repo.planRows(addons);
      expect(rows.length, 1); // only addon a
      expect(rows.first.addonId, 'a');
      expect(rows.first.isLoading, isTrue);
    });

    test('fetchRow loads items and clears loading', () async {
      final httpMock = _httpFor({
        'catalog/movie/popular':
            '{"metas":[{"id":"tt1","type":"movie","name":"Test"}]}',
      });
      final repo = CatalogRepository(api: AddonApi(httpMock));
      final row = CatalogRow(
        addonId: 'a',
        addonName: 'a',
        type: 'movie',
        catalogId: 'popular',
        catalogName: 'Popular',
        isLoading: true,
      );
      final result = await repo.fetchRow(row, [_addon('a', 'a.test')]);
      final updated = result.valueOrNull!;
      expect(updated.isLoading, isFalse);
      expect(updated.items.length, 1);
    });
  });

  group('WatchProgressStore', () {
    late LocalStore store;
    late WatchProgressStore progressStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await LocalStore.create();
      progressStore = WatchProgressStore(store);
    });

    WatchProgress _p(String id, {int position = 100, int duration = 200}) {
      return WatchProgress(
        contentId: id,
        contentType: 'movie',
        positionMs: position,
        durationMs: duration,
        updatedAt: DateTime.now(),
      );
    }

    test('upsert inserts and updates', () async {
      await progressStore.upsert(_p('tt1', position: 100));
      await progressStore.upsert(_p('tt1', position: 500));
      final all = await progressStore.getAll();
      expect(all.length, 1);
      expect(all.first.positionMs, 500);
    });

    test('movie and episode progress are separate keys', () async {
      await progressStore.upsert(_p('tt1'));
      await progressStore.upsert(_p('tt1'), );
      // same key - updated
      await progressStore.upsert(WatchProgress(
        contentId: 'tt1',
        contentType: 'series',
        videoId: 'tt1:1:1',
        positionMs: 50,
        durationMs: 100,
        updatedAt: DateTime.now(),
      ));
      final all = await progressStore.getAll();
      expect(all.length, 2);
    });

    test('remove deletes only the target', () async {
      await progressStore.upsert(_p('tt1'));
      await progressStore.upsert(_p('tt2'));
      await progressStore.remove('tt1');
      final all = await progressStore.getAll();
      expect(all.length, 1);
      expect(all.first.contentId, 'tt2');
    });

    test('persists across instances', () async {
      await progressStore.upsert(_p('tt1'));
      final fresh = WatchProgressStore(store);
      expect((await fresh.getAll()).length, 1);
    });
  });

  group('WatchedItemsStore', () {
    late LocalStore store;
    late WatchedItemsStore watched;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await LocalStore.create();
      watched = WatchedItemsStore(store);
    });

    test('markWatched whole item', () async {
      await watched.markWatched('tt1', 'movie');
      expect(await watched.isWatched('tt1'), isTrue);
    });

    test('markWatched episode tracks per-episode', () async {
      await watched.markWatched('tt1', 'series', videoId: 'tt1:1:1');
      expect(await watched.isWatched('tt1', videoId: 'tt1:1:1'), isTrue);
      expect(await watched.isWatched('tt1', videoId: 'tt1:1:2'), isFalse);
      expect(await watched.isWatched('tt1'), isTrue); // item-level marker
    });

    test('markUnwatched removes item or episode', () async {
      await watched.markWatched('tt1', 'series', videoId: 'tt1:1:1');
      await watched.markWatched('tt1', 'series', videoId: 'tt1:1:2');
      await watched.markUnwatched('tt1', videoId: 'tt1:1:1');
      expect(await watched.isWatched('tt1', videoId: 'tt1:1:1'), isFalse);
      expect(await watched.isWatched('tt1', videoId: 'tt1:1:2'), isTrue);
      await watched.markUnwatched('tt1');
      expect(await watched.isWatched('tt1'), isFalse);
    });
  });
}
