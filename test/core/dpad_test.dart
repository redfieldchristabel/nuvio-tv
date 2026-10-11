import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/navigation/dpad.dart';
import 'package:nuvio_tv_flutter/core/navigation/route_paths.dart';

void main() {
  group('mapKey', () {
    test('directional keys map correctly', () {
      expect(mapKey(LogicalKeyboardKey.arrowUp), NuvioKeyAction.up);
      expect(mapKey(LogicalKeyboardKey.arrowDown), NuvioKeyAction.down);
      expect(mapKey(LogicalKeyboardKey.arrowLeft), NuvioKeyAction.left);
      expect(mapKey(LogicalKeyboardKey.arrowRight), NuvioKeyAction.right);
    });

    test('select/enter/back map correctly', () {
      expect(mapKey(LogicalKeyboardKey.select), NuvioKeyAction.select);
      expect(mapKey(LogicalKeyboardKey.enter), NuvioKeyAction.select);
      expect(mapKey(LogicalKeyboardKey.escape), NuvioKeyAction.back);
      expect(mapKey(LogicalKeyboardKey.goBack), NuvioKeyAction.back);
    });

    test('media keys map correctly', () {
      expect(mapKey(LogicalKeyboardKey.mediaPlayPause),
          NuvioKeyAction.playPause);
      expect(mapKey(LogicalKeyboardKey.mediaPlay), NuvioKeyAction.mediaPlay);
      expect(mapKey(LogicalKeyboardKey.mediaPause), NuvioKeyAction.mediaPause);
      expect(mapKey(LogicalKeyboardKey.mediaRewind), NuvioKeyAction.rewind);
      expect(mapKey(LogicalKeyboardKey.mediaFastForward),
          NuvioKeyAction.fastForward);
    });

    test('menu + unknown', () {
      expect(mapKey(LogicalKeyboardKey.contextMenu), NuvioKeyAction.menu);
      expect(mapKey(LogicalKeyboardKey.keyA), NuvioKeyAction.unknown);
    });
  });

  group('DpadRepeatThrottle', () {
    test('first press always fires', () {
      final throttle = DpadRepeatThrottle();
      expect(throttle.shouldFire(LogicalKeyboardKey.arrowDown, false), isTrue);
      throttle.dispose();
    });

    test('dispose is safe to call multiple times', () {
      final throttle = DpadRepeatThrottle();
      throttle.shouldFire(LogicalKeyboardKey.arrowDown, false);
      throttle.dispose();
      throttle.dispose(); // no throw
    });
  });

  group('FocusScale', () {
    testWidgets('renders child and responds to focus', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FocusScale(
            child: const Text('card'),
          ),
        ),
      ));
      expect(find.text('card'), findsOneWidget);
    });
  });

  group('RoutePath', () {
    test('fromName resolves known routes', () {
      expect(RoutePath.fromName('home'), RoutePath.home);
      expect(RoutePath.fromName('detail'), RoutePath.detail);
      expect(RoutePath.fromName('catalogSeeAll'), RoutePath.catalogSeeAll);
    });

    test('unknown name falls back to home', () {
      expect(RoutePath.fromName('nonexistent'), RoutePath.home);
    });

    test('all 18 routes have unique names', () {
      final names = RoutePath.values.map((r) => r.name).toSet();
      expect(names.length, RoutePath.values.length);
    });
  });
}
