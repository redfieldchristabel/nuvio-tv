import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';

/// Scrobble thresholds, ported from the official clients.
///
/// Trakt scrobbles: start at 10%, pause at 80% (scrobble = complete).
/// Simkl completes at 80%.
class ScrobblePolicy {
  const ScrobblePolicy._();

  static const traktStartThreshold = 0.10;
  static const traktScrobbleThreshold = 0.80;
  static const simklCompleteThreshold = 0.80;

  /// Which scrobble action applies at [fraction].
  static TraktScrobbleAction traktAction(double fraction) {
    if (fraction >= traktScrobbleThreshold) {
      return TraktScrobbleAction.scrobble;
    }
    if (fraction >= traktStartThreshold) {
      return TraktScrobbleAction.start;
    }
    return TraktScrobbleAction.none;
  }

  static bool simklShouldComplete(double fraction) =>
      fraction >= simklCompleteThreshold;
}

enum TraktScrobbleAction { none, start, pause, scrobble }

/// Trakt OAuth device flow + scrobble + watchlist.
class TraktService {
  TraktService(this._http, {required this.clientId, required this.clientSecret});

  final HttpClient _http;
  final String clientId;
  final String clientSecret;

  static const _base = 'https://api.trakt.tv';
  static const _deviceCodeUrl = '$_base/oauth/device/code';
  static const _scrobbleUrl = '$_base/scrobble';
  static const _syncUrl = '$_base/sync';

  Map<String, String> _headers({String? accessToken}) => {
        'content-type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': clientId,
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  /// Step 1 of device flow: get user_code + verification_url.
  Future<Result<TraktDeviceCode>> startDeviceFlow() async {
    final result = await _http.postJson(
      Uri.parse(_deviceCodeUrl),
      body: {'client_id': clientId},
      headers: _headers(),
    );
    if (result.isErr) return Result.err(result.errorOrNull!);
    final data = result.valueOrNull;
    if (data is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Device code response invalid'));
    }
    return Result.ok(TraktDeviceCode(
      deviceCode: data['device_code'] as String? ?? '',
      userCode: data['user_code'] as String? ?? '',
      verificationUrl:
          data['verification_url'] as String? ?? 'https://trakt.tv/activate',
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 600,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
    ));
  }

  /// Step 2: poll for the access token.
  Future<Result<TraktTokens>> pollForToken(String deviceCode) async {
    final result = await _http.postJson(
      Uri.parse('$_base/oauth/device/token'),
      body: {
        'code': deviceCode,
        'client_id': clientId,
        'client_secret': clientSecret,
      },
      headers: _headers(),
    );
    if (result.isErr) {
      // 404 = not yet approved (keep polling), 400 = denied/expired.
      final err = result.errorOrNull!;
      if (err.statusCode == 404) {
        return Result.err(AppError.http(404, 'pending'));
      }
      return Result.err(err);
    }
    final data = result.valueOrNull;
    if (data is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Token response invalid'));
    }
    return Result.ok(TraktTokens(
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String? ?? '',
      expiresInSeconds: (data['expires_in'] as num?)?.toInt() ?? 0,
    ));
  }

  /// Scrobble start/pause/stop for a movie or episode.
  Future<Result<bool>> scrobble({
    required String accessToken,
    required TraktScrobbleAction action,
    required String type,
    required String imdbId,
    double progressPercent = 0,
    int? season,
    int? episode,
  }) async {
    if (action == TraktScrobbleAction.none) return Result.ok(false);
    final String endpoint;
    switch (action) {
      case TraktScrobbleAction.start:
        endpoint = 'start';
      case TraktScrobbleAction.pause:
        endpoint = 'pause';
      case TraktScrobbleAction.scrobble:
        endpoint = 'stop';
      case TraktScrobbleAction.none:
        return Result.ok(false);
    }
    final mediaEntry = <String, dynamic>{
      'ids': {'imdb': imdbId},
    };
    final body = <String, dynamic>{
      'progress': (progressPercent * 100).clamp(0, 100).round(),
      if (type == 'series') 'show': mediaEntry else 'movie': mediaEntry,
      if (type == 'series') ...{
        'episode': {
          'season': season ?? 1,
          'number': episode ?? 1,
        },
      },
    };
    final result = await _http.postJson(
      Uri.parse('$_scrobbleUrl/$endpoint'),
      body: body,
      headers: _headers(accessToken: accessToken),
    );
    return Result.ok(result.isOk);
  }

  /// Add/remove an item from the watchlist.
  Future<Result<bool>> setWatchlist({
    required String accessToken,
    required String type,
    required String imdbId,
    required bool add,
  }) async {
    final result = await _http.postJson(
      Uri.parse('$_syncUrl/watchlist'),
      body: {
        type == 'series' ? 'shows' : 'movies': [
          {'ids': {'imdb': imdbId}}
        ]
      },
      headers: _headers(accessToken: accessToken),
    );
    return Result.ok(result.isOk);
  }
}

class TraktDeviceCode {
  const TraktDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final int expiresIn;
  final int interval;
}

class TraktTokens {
  const TraktTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;
}

/// Simkl OAuth + scrobble (completes at 80%).
class SimklService {
  SimklService(this._http, {required this.clientId});

  final HttpClient _http;
  final String clientId;

  static const _base = 'https://api.simkl.com';
  static const _deviceInitUrl = '$_base/oauth/pin';

  Map<String, String> _headers({String? accessToken}) => {
        'content-type': 'application/json',
        'simkl-api-key': clientId,
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<Result<SimklPin>> startDeviceFlow() async {
    final result = await _http.postJson(
      Uri.parse(_deviceInitUrl),
      body: {'redirect': 'urn:ietf:wg:oauth:2.0:oob'},
      headers: _headers(),
    );
    if (result.isErr) return Result.err(result.errorOrNull!);
    final data = result.valueOrNull;
    if (data is! Map<String, dynamic>) {
      return Result.err(AppError.parse('PIN response invalid'));
    }
    return Result.ok(SimklPin(
      userCode: data['user_code'] as String? ?? '',
      verificationUrl:
          data['verification_url'] as String? ?? 'https://simkl.com/pin',
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 600,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
    ));
  }

  Future<Result<TraktTokens>> pollForToken(String userCode) async {
    final result = await _http.postJson(
      Uri.parse('$_base/oauth/device/token'),
      body: {'pin': userCode},
      headers: _headers(),
    );
    if (result.isErr) return Result.err(result.errorOrNull!);
    final data = result.valueOrNull;
    if (data is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Token response invalid'));
    }
    return Result.ok(TraktTokens(
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String? ?? '',
      expiresInSeconds: (data['expires_in'] as num?)?.toInt() ?? 0,
    ));
  }

  /// Mark watched (complete) via /scrobble/checkin-equivalent.
  Future<Result<bool>> markWatched({
    required String accessToken,
    required String type,
    required String imdbId,
    double progressPercent = 100,
    int? season,
    int? episode,
  }) async {
    if (!ScrobblePolicy.simklShouldComplete(progressPercent / 100)) {
      return Result.ok(false);
    }
    final mediaEntry = <String, dynamic>{
      'ids': {'imdb': imdbId},
    };
    final result = await _http.postJson(
      Uri.parse('$_base/scrobble'),
      body: {
        'progress': progressPercent.round(),
        if (type == 'series') 'show': mediaEntry else 'movie': mediaEntry,
        if (type == 'series') ...{
          'episode': {
            'season': season ?? 1,
            'number': episode ?? 1,
          },
        },
      },
      headers: _headers(accessToken: accessToken),
    );
    return Result.ok(result.isOk);
  }
}

class SimklPin {
  const SimklPin({
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.interval,
  });

  final String userCode;
  final String verificationUrl;
  final int expiresIn;
  final int interval;
}

/// MDBList ratings enrichment (API-key auth).
class MdbListService {
  MdbListService(this._http, {required this.apiKey});

  final HttpClient _http;
  final String apiKey;

  static const _base = 'https://api.mdblist.com';

  /// Ratings for an imdb id: {imdb_id, ratings: [{source, value}...]}.
  Future<Result<MdbListRatings>> getRatings(String imdbId) async {
    final result = await _http.getJson(
      Uri.parse('$_base/imdb/$imdbId/ratings?apikey=$apiKey'),
    );
    if (result.isErr) return Result.err(result.errorOrNull!);
    final data = result.valueOrNull;
    if (data is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Ratings response invalid'));
    }
    final scores = <String, double>{};
    final ratings = (data['ratings'] as List<dynamic>?) ?? const [];
    for (final r in ratings.whereType<Map<String, dynamic>>()) {
      final source = r['source'] as String?;
      final value = (r['value'] as num?)?.toDouble();
      if (source != null && value != null) {
        scores[source.toLowerCase()] = value;
      }
    }
    return Result.ok(MdbListRatings(imdbId: imdbId, scores: scores));
  }
}

class MdbListRatings {
  const MdbListRatings({required this.imdbId, required this.scores});

  final String imdbId;

  /// source (lowercase, e.g. 'imdb', 'tmdb', 'trakt') -> score.
  final Map<String, double> scores;

  double? operator [](String source) => scores[source.toLowerCase()];
}
