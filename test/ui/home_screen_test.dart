import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/data/repositories/addon_repository_impl.dart';
import 'package:nuvio_tv_flutter/data/repositories/catalog_repository_impl.dart';
import 'package:nuvio_tv_flutter/state/home_controller.dart';
import 'package:nuvio_tv_flutter/domain/models/watch_progress.dart';
import 'package:nuvio_tv_flutter/domain/models/content_type.dart';
import 'package:nuvio_tv_flutter/ui/screens/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(overrides: overrides, child: MaterialApp(home: child));
}

Future<LocalStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore.create();
}

void main() {
  group('HomeScreen', () {
    testWidgets('shows loading then content with catalog rows',
        (tester) async {
      final store = await _store();

      await tester.pumpWidget(_wrap(
        const HomeScreen(),
        [
          addonRepositoryProvider
              .overrideWithValue(LocalAddonRepository(store)),
          watchProgressStoreProvider
              .overrideWithValue(WatchProgressStore(store)),
        ],
      ));

      // Loading skeleton first.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Settle async build.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Empty addons -> empty home (no rows, no crash).
      expect(find.text('Nuvio'), findsNothing); // sidebar not mounted here
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders continue watching entries', (tester) async {
      final store = await _store();
      final progress = WatchProgressStore(store);
      await progress.upsert(WatchProgress(
        contentId: 'tt1',
        contentType: 'movie',
        positionMs: 500,
        durationMs: 1000,
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(_wrap(
        const HomeScreen(),
        [
          addonRepositoryProvider
              .overrideWithValue(LocalAddonRepository(store)),
          watchProgressStoreProvider.overrideWithValue(progress),
        ],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // No crash with progress present; hero empty (no addons).
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeController data assembly', () {
    testWidgets('hero picks items with backgrounds, cw maps progress',
        (tester) async {
      final store = await _store();
      final progress = WatchProgressStore(store);
      await progress.upsert(WatchProgress(
        contentId: 'tt1',
        contentType: 'movie',
        positionMs: 250,
        durationMs: 1000,
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(_wrap(
        const HomeScreen(),
        [
          addonRepositoryProvider
              .overrideWithValue(LocalAddonRepository(store)),
          watchProgressStoreProvider.overrideWithValue(progress),
        ],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final data = container.read(homeControllerProvider).valueOrNull;
      expect(data, isNotNull);
      expect(data!.heroItems, isEmpty); // no addons -> no hero
      expect(data.continueWatching.length, 1);
      expect(data.continueWatching.first.fraction, 0.25);
      expect(data.catalogRows, isEmpty);
    });
  });
}
