/// The kind of media a catalog item, meta preview or stream refers to.
enum ContentType {
  movie,
  series,
  channel,
  tv;

  static ContentType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'movie':
        return ContentType.movie;
      case 'series':
        return ContentType.series;
      case 'channel':
        return ContentType.channel;
      case 'tv':
        return ContentType.tv;
      default:
        return ContentType.movie;
    }
  }

  String get wireName {
    switch (this) {
      case ContentType.movie:
        return 'movie';
      case ContentType.series:
        return 'series';
      case ContentType.channel:
        return 'channel';
      case ContentType.tv:
        return 'tv';
    }
  }

  bool get isSeries => this == ContentType.series || this == ContentType.tv;
}
