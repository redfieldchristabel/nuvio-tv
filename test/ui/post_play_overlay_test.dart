import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/domain/models/content_type.dart';
import 'package:nuvio_tv_flutter/domain/models/meta.dart';
import 'package:nuvio_tv_flutter/ui/screens/player/post_play_overlay.dart';

void main() {
  group('PostPlayPolicy.shouldShow', () {
    test('playbackEnded always shows', () {
      expect(
        PostPlayPolicy.shouldShow(
          isSeries: false,
          position: Duration.zero,
          duration: const Duration(minutes: 90),
          playbackEnded: true,
        ),
        isTrue,
      );
    });

    test('movie shows at threshold (98%)', () {
      final duration = const Duration(minutes: 100);
      expect(
        PostPlayPolicy.shouldShow(
          isSeries: false,
          position: const Duration(minutes: 97),
          duration: duration,
        ),
        isFalse,
      );
      expect(
        PostPlayPolicy.shouldShow(
          isSeries: false,
          position: const Duration(minutes: 98, seconds: 30),
          duration: duration,
        ),
        isTrue,
      );
    });

    test('series requires seriesThresholdReached', () {
      final duration = const Duration(minutes: 45);
      expect(
        PostPlayPolicy.shouldShow(
          isSeries: true,
          position: const Duration(minutes: 44),
          duration: duration,
          seriesThresholdReached: false,
        ),
        isFalse,
      );
      expect(
        PostPlayPolicy.shouldShow(
          isSeries: true,
          position: const Duration(minutes: 40),
          duration: duration,
          seriesThresholdReached: true,
        ),
        isTrue,
      );
    });

    test('zero duration never shows (except ended)', () {
      expect(
        PostPlayPolicy.shouldShow(
          isSeries: false,
          position: Duration.zero,
          duration: Duration.zero,
        ),
        isFalse,
      );
    });
  });

  group('PostPlayPolicy.countdownSeconds', () {
    test('null until final 5 seconds', () {
      final duration = const Duration(minutes: 10);
      expect(
        PostPlayPolicy.countdownSeconds(
            const Duration(minutes: 9), duration),
        isNull,
      );
      expect(
        PostPlayPolicy.countdownSeconds(
            const Duration(minutes: 9, seconds: 54), duration),
        isNull,
      ); // 6s remaining: not yet
      expect(
        PostPlayPolicy.countdownSeconds(
            const Duration(minutes: 9, seconds: 55), duration),
        5,
      ); // exactly 5s: countdown starts
    });

    test('counts 5..1 in final seconds', () {
      final duration = const Duration(minutes: 10);
      expect(
        PostPlayPolicy.countdownSeconds(
            const Duration(minutes: 9, seconds: 56), duration),
        4,
      );
      expect(
        PostPlayPolicy.countdownSeconds(
            const Duration(minutes: 9, seconds: 59), duration),
        1,
      );
    });
  });

  group('PostPlayPolicy.shouldPrefetch', () {
    test('prefetches at 90% or 10 min remaining', () {
      final duration = const Duration(minutes: 100);
      expect(
        PostPlayPolicy.shouldPrefetch(
          position: const Duration(minutes: 50),
          duration: duration,
        ),
        isFalse,
      );
      expect(
        PostPlayPolicy.shouldPrefetch(
          position: const Duration(minutes: 91),
          duration: duration,
        ),
        isTrue,
      );
      // 10 min remaining on a 100 min movie = 90% (covered above).
      // Short video: 5 min total, 3 min in = 2 min remaining.
      expect(
        PostPlayPolicy.shouldPrefetch(
          position: const Duration(minutes: 3),
          duration: const Duration(minutes: 5),
        ),
        isTrue,
      );
    });
  });

  group('PostPlayOverlay widget', () {
    MetaPreview _preview(String id, String name) => MetaPreview(
          id: id,
          type: ContentType.movie,
          name: name,
        );

    testWidgets('renders finished title with actions', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PostPlayOverlay(
            title: 'Some Movie',
            recommendations: const [],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('You finished watching'), findsOneWidget);
      expect(find.text('Some Movie'), findsOneWidget);
      expect(find.text('Watch again'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Play now'), findsNothing); // movie: no next episode
    });

    testWidgets('series shows up-next with countdown', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PostPlayOverlay(
            title: 'Some Show',
            nextEpisodeLabel: 'S1:E2 · The Next One',
            countdownSeconds: 5,
            recommendations: const [],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('S1:E2 · The Next One'), findsOneWidget);
      expect(find.text('Play now'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // countdown ring
    });

    testWidgets('recommendations row renders posters', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PostPlayOverlay(
            title: 'Some Movie',
            recommendations: [
              _preview('tt1', 'Rec One'),
              _preview('tt2', 'Rec Two'),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('More like this'), findsOneWidget);
      expect(find.text('Rec One'), findsOneWidget);
      expect(find.text('Rec Two'), findsOneWidget);
    });
  });
}
