import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/tracking/tracking_services.dart';

void main() {
  group('ScrobblePolicy', () {
    test('trakt thresholds match official', () {
      expect(ScrobblePolicy.traktAction(0.05), TraktScrobbleAction.none);
      expect(
          ScrobblePolicy.traktAction(0.10), TraktScrobbleAction.start);
      expect(
          ScrobblePolicy.traktAction(0.50), TraktScrobbleAction.start);
      expect(
          ScrobblePolicy.traktAction(0.79), TraktScrobbleAction.start);
      expect(
          ScrobblePolicy.traktAction(0.80), TraktScrobbleAction.scrobble);
      expect(
          ScrobblePolicy.traktAction(0.95), TraktScrobbleAction.scrobble);
    });

    test('simkl completes at 80%', () {
      expect(ScrobblePolicy.simklShouldComplete(0.79), isFalse);
      expect(ScrobblePolicy.simklShouldComplete(0.80), isTrue);
      expect(ScrobblePolicy.simklShouldComplete(1.0), isTrue);
    });
  });

  group('MdbListRatings', () {
    test('case-insensitive source lookup', () {
      final ratings = MdbListRatings(imdbId: 'tt1', scores: {
        'imdb': 8.5,
        'tmdb': 7.9,
        'trakt': 8.0,
      });
      expect(ratings['IMDB'], 8.5);
      expect(ratings['tmdb'], 7.9);
      expect(ratings['Trakt'], 8.0);
      expect(ratings['unknown'], isNull);
    });
  });
}
