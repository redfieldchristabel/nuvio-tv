import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/domain/models/user_profile.dart';
import 'package:nuvio_tv_flutter/state/settings_controller.dart';
import 'package:nuvio_tv_flutter/ui/screens/onboarding/onboarding_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.create();
  });

  Widget _wrap(Widget child) {
    return ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: MaterialApp(home: child),
    );
  }

  group('ExperienceModeSelectionScreen', () {
    testWidgets('renders all three modes', (tester) async {
      await tester.pumpWidget(_wrap(ExperienceModeSelectionScreen(
        onSelected: (_) {},
      )));
      await tester.pump();

      expect(find.text('Welcome to Nuvio'), findsOneWidget);
      expect(find.text('Modern'), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
    });

    testWidgets('tapping a mode persists it and calls back', (tester) async {
      ExperienceMode? selected;
      await tester.pumpWidget(_wrap(ExperienceModeSelectionScreen(
        onSelected: (mode) => selected = mode,
      )));
      await tester.pump();

      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();

      expect(selected, ExperienceMode.grid);
      // Persisted.
      final container = ProviderScope.containerOf(
        tester.element(find.text('Grid')),
      );
      final settings = container.read(settingsProvider).valueOrNull;
      expect(settings!.experienceMode, ExperienceMode.grid);
    });
  });

  group('EssentialAddonSetupScreen', () {
    testWidgets('renders suggestions with first preselected', (tester) async {
      await tester.pumpWidget(_wrap(EssentialAddonSetupScreen(
        onFinished: () {},
      )));
      await tester.pump();

      expect(find.text('Add your first sources'), findsOneWidget);
      expect(find.text('Cinemeta'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget); // first checked
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });

    testWidgets('toggles selection and finishes', (tester) async {
      var finished = false;
      await tester.pumpWidget(_wrap(EssentialAddonSetupScreen(
        onFinished: () => finished = true,
      )));
      await tester.pump();

      await tester.tap(find.text('Cinemeta Trailers'));
      await tester.pump();
      // Both checked now.
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));

      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
    });
  });
}
