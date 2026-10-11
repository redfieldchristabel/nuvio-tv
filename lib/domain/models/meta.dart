import 'content_type.dart';
import 'video.dart';

/// A full metadata record for a movie or series (Stremio meta detail shape).
class Meta {
  const Meta({
    required this.id,
    required this.type,
    this.name,
    this.poster,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.imdbRating,
    this.runtime,
    this.genres = const [],
    this.cast = const [],
    this.director = const [],
    this.writer = const [],
    this.videos = const [],
    this.trailerStreams = const [],
    this.imdbId,
    this.tmdbId,
    this.popular = false,
  });

  final String id;
  final ContentType type;
  final String? name;
  final String? poster;
  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final String? imdbRating;
  final String? runtime;
  final List<String> genres;
  final List<String> cast;
  final List<String> director;
  final List<String> writer;
  final List<Video> videos;
  final List<Video> trailerStreams;
  final String? imdbId;
  final String? tmdbId;
  final bool popular;

  Meta copyWith({
    String? id,
    ContentType? type,
    String? name,
    String? poster,
    String? background,
    String? logo,
    String? description,
    String? releaseInfo,
    String? imdbRating,
    String? runtime,
    List<String>? genres,
    List<String>? cast,
    List<String>? director,
    List<String>? writer,
    List<Video>? videos,
    List<Video>? trailerStreams,
    String? imdbId,
    String? tmdbId,
    bool? popular,
  }) {
    return Meta(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      poster: poster ?? this.poster,
      background: background ?? this.background,
      logo: logo ?? this.logo,
      description: description ?? this.description,
      releaseInfo: releaseInfo ?? this.releaseInfo,
      imdbRating: imdbRating ?? this.imdbRating,
      runtime: runtime ?? this.runtime,
      genres: genres ?? this.genres,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      writer: writer ?? this.writer,
      videos: videos ?? this.videos,
      trailerStreams: trailerStreams ?? this.trailerStreams,
      imdbId: imdbId ?? this.imdbId,
      tmdbId: tmdbId ?? this.tmdbId,
      popular: popular ?? this.popular,
    );
  }

  static Meta fromJson(Map<String, dynamic> json) {
    final type = ContentType.fromString(json['type'] as String?);
    final videos = (json['videos'] as List<dynamic>?)
            ?.map((e) => Video.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <Video>[];
    return Meta(
      id: (json['id'] as String?) ?? '',
      type: type,
      name: json['name'] as String?,
      poster: json['poster'] as String?,
      background: (json['background'] ?? json['backdrop']) as String?,
      logo: json['logo'] as String?,
      description: json['description'] as String?,
      releaseInfo: (json['releaseInfo'] ?? json['release_info']) as String?,
      imdbRating: (json['imdbRating'] ?? json['imdb_rating'])?.toString(),
      runtime: json['runtime'] as String?,
      genres: _stringList(json['genres']),
      cast: _stringList(json['cast']),
      director: _stringList(json['director']),
      writer: _stringList(json['writer']),
      videos: videos,
      trailerStreams: (json['trailerStreams'] as List<dynamic>?)
              ?.map((e) => Video.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Video>[],
      imdbId: json['imdbId'] as String?,
      tmdbId: json['tmdbId']?.toString(),
      popular: json['popular'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wireName,
        if (name != null) 'name': name,
        if (poster != null) 'poster': poster,
        if (background != null) 'background': background,
        if (logo != null) 'logo': logo,
        if (description != null) 'description': description,
        if (releaseInfo != null) 'releaseInfo': releaseInfo,
        if (imdbRating != null) 'imdbRating': imdbRating,
        if (runtime != null) 'runtime': runtime,
        if (genres.isNotEmpty) 'genres': genres,
        if (cast.isNotEmpty) 'cast': cast,
        if (director.isNotEmpty) 'director': director,
        if (writer.isNotEmpty) 'writer': writer,
        if (videos.isNotEmpty) 'videos': videos.map((v) => v.toJson()).toList(),
        if (imdbId != null) 'imdbId': imdbId,
        if (tmdbId != null) 'tmdbId': tmdbId,
      };

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      // Some addons return comma-separated strings.
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}

/// Lightweight poster-card variant of [Meta] used in catalog rows.
class MetaPreview {
  const MetaPreview({
    required this.id,
    required this.type,
    this.name,
    this.poster,
    this.background,
    this.releaseInfo,
    this.imdbRating,
    this.description,
    this.logo,
  });

  final String id;
  final ContentType type;
  final String? name;
  final String? poster;
  final String? background;
  final String? releaseInfo;
  final String? imdbRating;
  final String? description;
  final String? logo;

  factory MetaPreview.fromJson(Map<String, dynamic> json) {
    return MetaPreview(
      id: (json['id'] as String?) ?? '',
      type: ContentType.fromString(json['type'] as String?),
      name: json['name'] as String?,
      poster: json['poster'] as String?,
      background: (json['background'] ?? json['backdrop']) as String?,
      releaseInfo: (json['releaseInfo'] ?? json['release_info']) as String?,
      imdbRating: (json['imdbRating'] ?? json['imdb_rating'])?.toString(),
      description: json['description'] as String?,
      logo: json['logo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wireName,
        if (name != null) 'name': name,
        if (poster != null) 'poster': poster,
        if (background != null) 'background': background,
        if (releaseInfo != null) 'releaseInfo': releaseInfo,
        if (imdbRating != null) 'imdbRating': imdbRating,
        if (description != null) 'description': description,
        if (logo != null) 'logo': logo,
      };
}
