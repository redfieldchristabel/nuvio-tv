import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/debrid/debrid_service.dart';
import 'package:nuvio_tv_flutter/domain/models/user_profile.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/core/plugin/plugin_models.dart';
import 'package:nuvio_tv_flutter/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.create();
    container = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
  });

  group('SettingsController', () {
    test('defaults when nothing stored', () async {
      final settings = await container.read(settingsProvider.future);
      expect(settings.experienceMode, ExperienceMode.modern);
      expect(settings.skipIntervalSeconds, 10);
      expect(settings.autoPlayNext, isTrue);
      expect(settings.autoPlayMode, 'MANUAL');
      expect(settings.p2pEnabled, isFalse);
    });

    test('modify persists and updates state', () async {
      await container
          .read(settingsProvider.notifier)
          .modify((s) => s.copyWith(skipIntervalSeconds: 30, p2pEnabled: true));

      final settings = container.read(settingsProvider).valueOrNull!;
      expect(settings.skipIntervalSeconds, 30);
      expect(settings.p2pEnabled, isTrue);

      // Persisted: fresh controller reads the same values.
      final container2 = ProviderContainer(overrides: [
        localStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container2.dispose);
      final restored = await container2.read(settingsProvider.future);
      expect(restored.skipIntervalSeconds, 30);
      expect(restored.p2pEnabled, isTrue);
    });

    test('corrupt stored json falls back to defaults', () async {
      await store.setString(StorageKeys.tmdbSettings, '{corrupt');
      final container2 = ProviderContainer(overrides: [
        localStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container2.dispose);
      final settings = await container2.read(settingsProvider.future);
      expect(settings.skipIntervalSeconds, 10);
    });
  });

  group('DebridAccountsController', () {
    test('connect and disconnect persist', () async {
      final notifier = container.read(debridAccountsProvider.notifier);
      final account = DebridAccount(
        providerId: DebridProviderId.realdebrid,
        apiKey: 'testkey12345',
        connectedAt: DateTime.now(),
      );
      await notifier.connect(account);

      final connected = container.read(debridAccountsProvider).valueOrNull!;
      expect(connected[DebridProviderId.realdebrid], isNotNull);
      expect(connected[DebridProviderId.realdebrid]!.apiKey, 'testkey12345');

      await notifier.disconnect(DebridProviderId.realdebrid);
      expect(
          container.read(debridAccountsProvider).valueOrNull!.containsKey(
              DebridProviderId.realdebrid), isFalse);
    });
  });

  group('PluginStateController', () {
    test('addRepository normalizes and persists', () async {
      final notifier = container.read(pluginStateProvider.notifier);
      await notifier.addRepository(
        const PluginRepository(id: 'r1', name: 'R1', url: 'https://r.test/'),
        [
          const Scraper(
              id: 's1', repositoryId: 'r1', name: 'S1', code: 'function x(){}'),
        ],
      );

      final state = container.read(pluginStateProvider).valueOrNull!;
      expect(state.repositories.length, 1);
      expect(state.scrapers.length, 1);

      // Remove cleans scrapers too.
      await notifier.removeRepository('r1');
      final after = container.read(pluginStateProvider).valueOrNull!;
      expect(after.repositories, isEmpty);
      expect(after.scrapers, isEmpty);
    });

    test('setScraperEnabled toggles', () async {
      final notifier = container.read(pluginStateProvider.notifier);
      await notifier.addRepository(
        const PluginRepository(id: 'r1', name: 'R1', url: 'https://r.test/'),
        [
          const Scraper(
              id: 's1', repositoryId: 'r1', name: 'S1', code: 'function x(){}'),
        ],
      );
      await notifier.setScraperEnabled('s1', false);
      final state = container.read(pluginStateProvider).valueOrNull!;
      expect(state.scrapers.first.enabled, isFalse);
    });
  });
}
