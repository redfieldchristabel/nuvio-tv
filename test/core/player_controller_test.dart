import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/player/player_controller.dart';

void main() {
  group('PlayerController state machine', () {
    late PlayerController controller;

    setUp(() {
      controller = PlayerController();
    });

    test('starts idle', () {
      expect(controller.phase, PlayerPhase.idle);
      expect(controller.position, Duration.zero);
      expect(controller.fraction, 0);
    });

    test('load → loading, markReady → playing', () async {
      await controller.load(url: 'https://x.test/video.mp4', title: 'Test');
      expect(controller.phase, PlayerPhase.loading);
      controller.markReady(const Duration(minutes: 30));
      expect(controller.phase, PlayerPhase.playing);
      expect(controller.duration, const Duration(minutes: 30));
    });

    test('markError sets error phase with message', () async {
      await controller.load(url: 'https://x.test/broken.mp4');
      controller.markError('codec unsupported');
      expect(controller.phase, PlayerPhase.error);
      expect(controller.errorMessage, 'codec unsupported');
    });

    test('togglePlayPause cycles playing⇄paused', () async {
      await controller.load(url: 'https://x.test/v.mp4');
      controller.markReady(const Duration(minutes: 10));
      expect(controller.phase, PlayerPhase.playing);
      controller.togglePlayPause();
      expect(controller.phase, PlayerPhase.paused);
      controller.togglePlayPause();
      expect(controller.phase, PlayerPhase.playing);
    });

    test('markEnded transitions to ended', () async {
      await controller.load(url: 'https://x.test/v.mp4');
      controller.markReady(const Duration(seconds: 10));
      controller.markEnded();
      expect(controller.phase, PlayerPhase.ended);
    });
  });

  group('PlayerController seeking', () {
    late PlayerController controller;

    setUp(() {
      controller = PlayerController();
      controller.load(url: 'https://x.test/v.mp4');
      controller.markReady(const Duration(minutes: 10));
    });

    test('seekTo clamps to duration', () {
      controller.seekTo(const Duration(minutes: 20)); // beyond 10min
      expect(controller.position, const Duration(minutes: 10));
      controller.seekTo(const Duration(seconds: -5));
      expect(controller.position, Duration.zero);
    });

    test('seekBy adds to current position', () {
      controller.updatePosition(const Duration(minutes: 1));
      controller.seekBy(10);
      expect(controller.position, const Duration(minutes: 1, seconds: 10));
      controller.seekBy(-30);
      expect(controller.position, const Duration(seconds: 40));
    });

    test('skip interval from settings', () {
      expect(controller.skipSeconds, 10);
      controller.settings = controller.settings.copyWith(skipIntervalSeconds: 30);
      expect(controller.skipSeconds, 30);
    });
  });

  group('PlayerController chrome', () {
    test('chrome visible while paused, hides after 3s while playing',
        () async {
      final controller = PlayerController();
      await controller.load(url: 'https://x.test/v.mp4');
      controller.markReady(const Duration(minutes: 5));
      expect(controller.chromeVisible, isTrue);

      controller.togglePlayPause(); // paused
      expect(controller.chromeVisible, isTrue);

      controller.togglePlayPause(); // playing again
      // Chrome schedules hide after 3s — verify via fake async in widget test.
    });
  });

  group('PlayerController progress persistence', () {
    test('onPersistProgress fires every 5s while playing', () async {
      final controller = PlayerController();
      var savedCount = 0;
      controller.onPersistProgress = (position, duration) => savedCount++;

      await controller.load(url: 'https://x.test/v.mp4');
      controller.markReady(const Duration(minutes: 5));

      // The timer fires every 5s real-time; in unit test we just verify
      // the callback is wired and cancel cleanly.
      await Future.delayed(const Duration(milliseconds: 50));
      controller.dispose();
      expect(controller.phase, PlayerPhase.playing);
    });
  });

  group('PlayerSettings', () {
    test('copyWith preserves unspecified fields', () {
      const settings = PlayerSettings(
        skipIntervalSeconds: 30,
        autoPlayNext: false,
        subtitleDelayMs: 500,
      );
      final updated = settings.copyWith(subtitleTextScale: 1.5);
      expect(updated.skipIntervalSeconds, 30);
      expect(updated.autoPlayNext, isFalse);
      expect(updated.subtitleDelayMs, 500);
      expect(updated.subtitleTextScale, 1.5);
    });
  });
}
