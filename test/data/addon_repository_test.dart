import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuvio_tv_flutter/data/remote/addon_api.dart';
import 'package:nuvio_tv_flutter/data/repositories/addon_repository_impl.dart';

const _manifestJson = '''
{
  "id": "com.cinemeta",
  "name": "Cinemeta",
  "version": "3.0.10",
  "types": ["movie", "series"],
  "catalogs": [{"id": "popular", "type": "movie", "name": "Popular"}],
  "resources": ["catalog", "meta", "stream"]
}
''';

Future<LocalStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore.create();
}

AddonRepository _repo(LocalStore store, {String? manifestBody}) {
  return LocalAddonRepository(
    store,
    api: AddonApi(HttpClient(
      maxRetries: 0,
      client: MockClient((request) async {
        if (request.url.path.endsWith('manifest.json')) {
          // Serve a manifest whose id derives from the host (a.test -> com.a).
          final host = request.url.host.split('.').first;
          final body = manifestBody ??
              _manifestJson.replaceFirst('com.cinemeta', 'com.' + host);
          return http.Response(body, 200);
        }
        return http.Response('nf', 404);
      }),
    )),
  );
}

void main() {
  group('LocalAddonRepository', () {
    late LocalStore store;

    setUp(() async {
      store = await _store();
    });

    test('install fetches manifest and persists', () async {
      final repo = _repo(store);
      final result = await repo.install('https://cinemeta.test/manifest.json');
      expect(result.isOk, isTrue);
      final addons = await repo.getAddons();
      expect(addons.length, 1);
      expect(addons.first.id, 'com.cinemeta');
      expect(addons.first.enabled, isTrue);
      expect(addons.first.orderIndex, 0);
    });

    test('install with invalid URL errors without persisting', () async {
      final repo = _repo(store);
      final result = await repo.install('not a url');
      expect(result.isErr, isTrue);
      expect(await repo.getAddons(), isEmpty);
    });

    test('re-install same addon updates not duplicates', () async {
      final repo = _repo(store);
      await repo.install('https://cinemeta.test/manifest.json');
      await repo.install('https://cinemeta.test/manifest.json');
      expect((await repo.getAddons()).length, 1);
    });

    test('remove deletes addon', () async {
      final repo = _repo(store);
      await repo.install('https://cinemeta.test/manifest.json');
      await repo.remove('com.cinemeta');
      expect(await repo.getAddons(), isEmpty);
    });

    test('setEnabled toggles without losing data', () async {
      final repo = _repo(store);
      await repo.install('https://cinemeta.test/manifest.json');
      await repo.setEnabled('com.cinemeta', false);
      final addons = await repo.getAddons();
      expect(addons.first.enabled, isFalse);
      expect(addons.first.name, 'Cinemeta'); // rest of data intact
    });

    test('setOrder reorders and preserves unmentioned', () async {
      final repo = _repo(store);
      // Install two different addons.
      await repo.install('https://a.test/manifest.json');
      await repo.install('https://b.test/manifest.json');
      await repo.setOrder(['com.b', 'com.a']);
      final addons = await repo.getAddons();
      expect(addons[0].id, 'com.b');
      expect(addons[0].orderIndex, 0);
      expect(addons[1].id, 'com.a');
      expect(addons[1].orderIndex, 1);
    });

    test('persists across repository instances (restart)', () async {
      final repo1 = _repo(store);
      await repo1.install('https://cinemeta.test/manifest.json');

      // New instance, same underlying store = app restart.
      final repo2 = _repo(store);
      final addons = await repo2.getAddons();
      expect(addons.length, 1);
      expect(addons.first.id, 'com.cinemeta');
    });

    test('watchAddons emits on install', () async {
      final repo = _repo(store);
      final emissions = <List<dynamic>>[];
      final sub = repo.watchAddons().listen(emissions.add);
      await repo.install('https://cinemeta.test/manifest.json');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emissions, isNotEmpty);
      expect(emissions.last.length, 1);
      await sub.cancel();
    });

    test('corrupt stored JSON degrades to empty list', () async {
      await store.setString(StorageKeys.addons, '{corrupt');
      final repo = _repo(store);
      expect(await repo.getAddons(), isEmpty);
    });
  });
}
