/// An episode or trailer entry attached to a [Meta] (Stremio 'videos' shape).
class Video {
  const Video({
    required this.id,
    this.title,
    this.season,
    this.episode,
    this.released,
    this.overview,
    this.thumbnail,
    this.duration,
    this.firstAired,
    this.tvdbId,
    this.imdbSeason,
    this.imdbEpisode,
  });

  final String id;
  final String? title;
  final int? season;
  final int? episode;
  final String? released;
  final String? overview;
  final String? thumbnail;
  final String? duration;
  final String? firstAired;
  final String? tvdbId;
  final int? imdbSeason;
  final int? imdbEpisode;

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: (json['id'] as String?) ?? '',
      title: json['title'] as String? ?? json['name'] as String?,
      season: _int(json['season']),
      episode: _int(json['episode']),
      released: json['released'] as String?,
      overview: json['overview'] as String? ?? json['description'] as String?,
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as String?,
      firstAired: json['firstAired'] as String?,
      tvdbId: json['tvdbId']?.toString(),
      imdbSeason: _int(json['imdbSeason']),
      imdbEpisode: _int(json['imdbEpisode']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (title != null) 'title': title,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (released != null) 'released': released,
        if (overview != null) 'overview': overview,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (duration != null) 'duration': duration,
        if (firstAired != null) 'firstAired': firstAired,
        if (tvdbId != null) 'tvdbId': tvdbId,
      };

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final doubleVal = double.tryParse(value);
      if (doubleVal != null) return doubleVal.toInt();
    }
    return null;
  }
}
