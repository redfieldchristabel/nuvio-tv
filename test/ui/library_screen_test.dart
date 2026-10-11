import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/data/repositories/addon_repository_impl.dart';
import 'package:nuvio_tv_flutter/data/repositories/catalog_repository_impl.dart';
import 'package:nuvio_tv_flutter/domain/models/watch_progress.dart';
import 'package:nuvio_tv_flutter/state/detail_controller.dart';
import 'package:nuvio_tv_flutter/state/home_controller.dart';
import 'package:nuvio_tv_flutter/state/library_controller.dart';
import 'package:nuvio_tv_flutter/ui/screens/library/library_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.create();
  });

  Widget _wrap(Widget child) {
    return ProviderScope(
      overrides: [
        addonRepositoryProvider
            .overrideWithValue(LocalAddonRepository(store)),
        watchProgressStoreProvider
            .overrideWithValue(WatchProgressStore(store)),
        watchedItemsStoreProvider
            .overrideWithValue(WatchedItemsStore(store)),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('empty library shows friendly message', (tester) async {
    await tester.pumpWidget(_wrap(const LibraryScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Watched'), findsOneWidget);
    expect(find.text('Collections'), findsOneWidget);
  });

  testWidgets('watched tab shows watched items', (tester) async {
    final watched = WatchedItemsStore(store);
    await watched.markWatched('tt1', 'movie');
    await watched.markWatched('tt2', 'movie');

    await tester.pumpWidget(_wrap(const LibraryScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Watched tab.
    await tester.tap(find.text('Watched'));
    await tester.pump(const Duration(milliseconds: 300));

    // No empty state on watched tab now.
    expect(find.text('Titles you finish will appear here.'), findsNothing);
  });

  testWidgets('saved tab shows in-progress items', (tester) async {
    final progress = WatchProgressStore(store);
    await progress.upsert(WatchProgress(
      contentId: 'tt1',
      contentType: 'movie',
      positionMs: 400,
      durationMs: 1000,
      updatedAt: DateTime.now(),
    ));

    await tester.pumpWidget(_wrap(const LibraryScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Saved tab is default; item present (no empty message).
    expect(find.text('Save titles from their detail page'), findsNothing);
  });

  testWidgets('LibraryController assembles data from stores',
      (tester) async {
    final container = ProviderContainer(overrides: [
      addonRepositoryProvider
          .overrideWithValue(LocalAddonRepository(store)),
      watchProgressStoreProvider
          .overrideWithValue(WatchProgressStore(store)),
      watchedItemsStoreProvider
          .overrideWithValue(WatchedItemsStore(store)),
    ]);
    addTearDown(container.dispose);

    final progress = container.read(watchProgressStoreProvider);
    await progress.upsert(WatchProgress(
      contentId: 'tt1',
      contentType: 'movie',
      positionMs: 400,
      durationMs: 1000,
      updatedAt: DateTime.now(),
    ));
    final watched = container.read(watchedItemsStoreProvider);
    await watched.markWatched('tt2', 'series');

    final data = await container.read(libraryControllerProvider.future);
    expect(data.saved.length, 1);
    expect(data.saved.first.contentId, 'tt1');
    expect(data.watched.length, 1);
    expect(data.watched.first.contentId, 'tt2');
  });
}
