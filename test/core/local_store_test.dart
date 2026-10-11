import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

/// Fake SharedPreferences-backed LocalStore for tests.
///
/// shared_preferences has an in-memory mock via setMockInitialValues.
class TestStore {
  static Future<LocalStore> create() async {
    SharedPreferences.setMockInitialValues({});
    return LocalStore.create();
  }
}


void main() {
  group('LocalStore', () {
    late LocalStore store;

    setUp(() async {
      store = await TestStore.create();
    });

    test('string round-trip', () async {
      expect(store.getString('k'), isNull);
      await store.setString('k', 'v');
      expect(store.getString('k'), 'v');
      expect(store.containsKey('k'), isTrue);
    });

    test('bool round-trip', () async {
      await store.setBool('flag', true);
      expect(store.getBool('flag'), isTrue);
      await store.setBool('flag', false);
      expect(store.getBool('flag'), isFalse);
    });

    test('int/double round-trip', () async {
      await store.setInt('n', 7);
      expect(store.getInt('n'), 7);
      await store.setDouble('d', 1.5);
      expect(store.getDouble('d'), 1.5);
    });

    test('string list round-trip', () async {
      await store.setStringList('list', ['a', 'b']);
      expect(store.getStringList('list'), ['a', 'b']);
    });

    test('remove deletes key', () async {
      await store.setString('gone', 'x');
      await store.remove('gone');
      expect(store.containsKey('gone'), isFalse);
    });

    test('json payload round-trip', () async {
      final payload = jsonEncode({'a': 1, 'b': [2, 3]});
      await store.setString('json', payload);
      expect(jsonDecode(store.getString('json')!), {'a': 1, 'b': [2, 3]});
    });
  });

  group('ProfileScopedStore', () {
    late LocalStore store;

    setUp(() async {
      store = await TestStore.create();
    });

    test('profiles are isolated', () async {
      final alice = ProfileScopedStore(store, 'alice');
      final bob = ProfileScopedStore(store, 'bob');

      await alice.setString(StorageKeys.addons, 'alice-data');
      await bob.setString(StorageKeys.addons, 'bob-data');

      expect(alice.getString(StorageKeys.addons), 'alice-data');
      expect(bob.getString(StorageKeys.addons), 'bob-data');
    });

    test('same base key different profiles distinct', () async {
      final p1 = ProfileScopedStore(store, 'p1');
      final p2 = ProfileScopedStore(store, 'p2');

      await p1.setBool(StorageKeys.onboardingComplete, true);
      expect(p2.getBool(StorageKeys.onboardingComplete), isNull);
    });

    test('remove only affects own namespace', () async {
      final a = ProfileScopedStore(store, 'a');
      final b = ProfileScopedStore(store, 'b');

      await a.setString('shared', 'a');
      await b.setString('shared', 'b');
      await a.remove('shared');

      expect(a.getString('shared'), isNull);
      expect(b.getString('shared'), 'b');
    });
  });
}
