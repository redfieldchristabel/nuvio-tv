import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';
import 'package:nuvio_tv_flutter/core/tracking/tracking_services.dart';
import 'package:nuvio_tv_flutter/domain/models/content_type.dart';
import 'package:nuvio_tv_flutter/domain/models/meta.dart';

/// Where "More Like This" recommendations come from.
///
/// The official clients let the user choose: Trakt (personalized, requires
/// auth) or TMDB (works without auth when a TMDB key is provisioned).
enum MoreLikeThisSource { trakt, tmdb }

/// "More Like This" recommendations for the detail screen.
///
/// Port of the official `fetchMoreLikeThis` + `fetchTraktRelated`:
/// - Trakt path: GET /{movies|shows}/{id}/related?extended=full,images
///   (id resolved from imdb id, trakt slug, or via /search/tmdb lookup)
/// - TMDB path: GET /{movie|tv}/{tmdbId}/recommendations
/// Results are capped (20 Trakt / 12 TMDB) and exclude the source title.
class MoreLikeThisService {
  MoreLikeThisService(this._http, {required this.trakt});

  final HttpClient _http;
  final TraktService trakt;

  static const _traktBase = 'https://api.trakt.tv';
  static const _tmdbBase = 'https://api.themoviedb.org/3';

  Map<String, String> _traktHeaders(String accessToken) => {
        'content-type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': trakt.clientId,
        'Authorization': 'Bearer $accessToken',
      };

  /// Fetch related titles. [traktAccessToken] null => falls back to TMDB
  /// when [tmdbApiKey] is provisioned; otherwise returns empty.
  Future<Result<List<MetaPreview>>> fetch({
    required String contentId,
    required ContentType contentType,
    String? traktAccessToken,
    String? tmdbApiKey,
    String? tmdbId,
    MoreLikeThisSource preferredSource = MoreLikeThisSource.trakt,
    int limit = 20,
  }) async {
    if (preferredSource == MoreLikeThisSource.trakt &&
        traktAccessToken != null &&
        traktAccessToken.isNotEmpty) {
      final result = await fetchTraktRelated(
        contentId: contentId,
        contentType: contentType,
        accessToken: traktAccessToken,
        limit: limit,
      );
      if (result.isOk && (result.valueOrNull?.isNotEmpty ?? false)) {
        return result;
      }
      // Trakt miss -> try TMDB fallback.
    }
    if (tmdbApiKey != null && tmdbApiKey.isNotEmpty) {
      return fetchTmdbRecommendations(
        contentId: contentId,
        contentType: contentType,
        tmdbApiKey: tmdbApiKey,
        tmdbId: tmdbId,
        limit: 12,
      );
    }
    return Result.ok(const []);
  }

  /// Trakt /related endpoint. Id resolution order: imdb id, trakt: prefix,
  /// slug, then /search/tmdb lookup when a tmdb: id is present.
  Future<Result<List<MetaPreview>>> fetchTraktRelated({
    required String contentId,
    required ContentType contentType,
    required String accessToken,
    int limit = 20,
  }) async {
    final apiType = contentType.isSeries ? 'shows' : 'movies';
    final pathId = _resolveTraktPathId(contentId);
    if (pathId == null || pathId.isEmpty) {
      return Result.ok(const []);
    }

    final uri = Uri.parse(
        '$_traktBase/$apiType/${Uri.encodeComponent(pathId)}'
        '/related?extended=full%2Cimages&page=1&limit=$limit');
    final result = await _http.getJson(uri, headers: _traktHeaders(accessToken));
    if (result.isErr) {
      // 404 = no related; not an error for UX purposes.
      if (result.errorOrNull?.statusCode == 404) {
        return Result.ok(const []);
      }
      return Result.err(result.errorOrNull!);
    }
    final payload = result.valueOrNull;
    if (payload is! List) return Result.ok(const []);

    final previews = <MetaPreview>[];
    for (final entry in payload.whereType<Map<String, dynamic>>()) {
      final preview = _traktRelatedPreview(entry, contentType);
      if (preview != null && preview.id != contentId) {
        previews.add(preview);
      }
    }
    return Result.ok(previews.take(limit).toList());
  }

  /// TMDB /recommendations endpoint.
  Future<Result<List<MetaPreview>>> fetchTmdbRecommendations({
    required String contentId,
    required ContentType contentType,
    required String tmdbApiKey,
    String? tmdbId,
    int limit = 12,
    String language = 'en-US',
  }) async {
    if (tmdbId == null || tmdbId.isEmpty) {
      return Result.ok(const []);
    }
    final type = contentType.isSeries ? 'tv' : 'movie';
    final uri = Uri.parse(
        '$_tmdbBase/$type/${Uri.encodeComponent(tmdbId)}'
        '/recommendations?api_key=${Uri.encodeComponent(tmdbApiKey)}'
        '&language=${Uri.encodeComponent(language)}&page=1');
    final result = await _http.getJson(uri);
    if (result.isErr) return Result.err(result.errorOrNull!);
    final data = result.valueOrNull;
    if (data is! Map<String, dynamic>) return Result.ok(const []);
    final results = (data['results'] as List<dynamic>?) ?? const [];

    final previews = <MetaPreview>[];
    for (final entry in results.whereType<Map<String, dynamic>>()) {
      final preview = _tmdbPreview(entry, contentType);
      if (preview != null && preview.id != contentId) {
        previews.add(preview);
      }
    }
    return Result.ok(previews.take(limit).toList());
  }

  /// Trakt path id: imdb:tt... -> tt..., trakt:slug -> slug, tmdb:123 -> null
  /// (needs lookup, unsupported here without extra call), plain slug -> slug.
  String? _resolveTraktPathId(String contentId) {
    final id = contentId.trim();
    if (id.isEmpty) return null;
    if (id.toLowerCase().startsWith('imdb:')) return id.substring(5);
    if (id.startsWith('tt')) return id;
    if (id.toLowerCase().startsWith('trakt:')) return id.substring(6);
    if (id.toLowerCase().startsWith('tmdb:')) return null;
    return id; // assume slug
  }

  /// Port of traktRelatedPreview: id from imdb > tmdb > trakt, name from
  /// title, artwork from images, year as releaseInfo.
  MetaPreview? _traktRelatedPreview(
      Map<String, dynamic> media, ContentType type) {
    final ids = (media['ids'] as Map<String, dynamic>?) ?? const {};
    final imdb = ids['imdb'] as String?;
    final tmdb = ids['tmdb'];
    final traktId = ids['trakt'];
    final id = imdb != null && imdb.isNotEmpty
        ? imdb
        : tmdb != null
            ? 'tmdb:$tmdb'
            : traktId != null
                ? 'trakt:$traktId'
                : '';
    final name = (media['title'] ?? media['original_title']) as String?;
    if (id.isEmpty || name == null || name.isEmpty) return null;

    final images = (media['images'] as Map<String, dynamic>?) ?? const {};
    final poster = _bestArtwork(images['poster']);
    final backdrop = _bestArtwork(images['fanart']);
    final year = media['year'];

    return MetaPreview(
      id: id,
      type: type,
      name: name,
      poster: poster,
      background: backdrop ?? poster,
      releaseInfo: year?.toString(),
    );
  }

  MetaPreview? _tmdbPreview(Map<String, dynamic> entry, ContentType type) {
    final id = entry['id']?.toString();
    final name =
        (entry['title'] ?? entry['name']) as String?;
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
    final posterPath = entry['poster_path'] as String?;
    final backdropPath = entry['backdrop_path'] as String?;
    final date = (entry['release_date'] ?? entry['first_air_date']) as String?;
    return MetaPreview(
      id: 'tmdb:$id',
      type: type,
      name: name,
      poster: posterPath != null
          ? 'https://image.tmdb.org/t/p/w342$posterPath'
          : null,
      background: backdropPath != null
          ? 'https://image.tmdb.org/t/p/w780$backdropPath'
          : null,
      releaseInfo: date == null || date.length < 4 ? null : date.substring(0, 4),
    );
  }

  /// Trakt images come as {medium, full}: pick full, then medium.
  String? _bestArtwork(dynamic images) {
    if (images is Map<String, dynamic>) {
      final full = images['full'] as String?;
      if (full != null && full.isNotEmpty) return full;
      final medium = images['medium'] as String?;
      if (medium != null && medium.isNotEmpty) return medium;
    }
    return null;
  }
}
