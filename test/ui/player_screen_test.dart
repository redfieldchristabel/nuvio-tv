import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/player/player_controller.dart';
import 'package:nuvio_tv_flutter/ui/screens/player/player_screen.dart';

void main() {
  testWidgets('PlayerScreen renders title and loading state',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerScreen(url: 'https://x.test/v.mp4', title: 'Test Movie'),
      ),
    );
    // Loading spinner shows immediately.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // No crash.
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlayerScreen chrome shows title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerScreen(url: 'https://x.test/v.mp4', title: 'My Title'),
      ),
    );
    await tester.pump();
    expect(find.text('My Title'), findsOneWidget);
  });

  testWidgets('PlayerScreen error state shows message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          url: 'https://x.test/broken.mp4',
          title: 'Broken',
          playerBuilder: (context) {
            // Simulate immediate error from platform player.
            context.controller.markError('codec unsupported');
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('codec unsupported'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('OK key toggles play/pause via controller', (tester) async {
    PlayerController? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          url: 'https://x.test/v.mp4',
          title: 'T',
          playerBuilder: (context) {
            captured ??= context.controller;
            if (captured!.phase == PlayerPhase.loading) {
              captured!.markReady(const Duration(minutes: 5));
            }
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.phase, PlayerPhase.playing);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(captured!.phase, PlayerPhase.paused);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(captured!.phase, PlayerPhase.playing);
  });

  testWidgets('right arrow seeks forward', (tester) async {
    PlayerController? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          url: 'https://x.test/v.mp4',
          title: 'T',
          playerBuilder: (context) {
            captured ??= context.controller;
            if (captured!.phase == PlayerPhase.loading) {
              captured!.markReady(const Duration(minutes: 10));
              captured!.updatePosition(const Duration(minutes: 1));
            }
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(captured!.position, const Duration(minutes: 1, seconds: 10));
  });

  testWidgets('escape pops the player', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    navigatorKey.currentState!.push(MaterialPageRoute(
      builder: (_) =>
          const PlayerScreen(url: 'https://x.test/v.mp4', title: 'T'),
    ));
    await tester.pump(); // start transition
    await tester.pump(const Duration(milliseconds: 400)); // finish
    expect(find.byType(PlayerScreen), findsOneWidget);

    // Verify keys reach the focus at all: select should toggle play/pause.
    // (Phase is loading here since no playerBuilder; toggle does nothing but
    //  proves the handler runs if we check chrome visibility instead.)
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(PlayerScreen), findsNothing);
  });
}
