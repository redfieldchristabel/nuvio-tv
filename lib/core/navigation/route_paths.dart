/// Typed route names mirroring the official router's 27 routes.
///
/// Only routes that exist in this port are wired; the rest are declared
/// for parity so the route table reads like the official one.
enum RoutePath {
  home('home'),
  player('player'),
  detail('detail'),
  library('library'),
  search('search'),
  discover('discover'),
  settings('settings'),
  stream('stream'),
  catalogSeeAll('catalogSeeAll'),
  plugin('plugin'),
  plugins('plugins'),
  catalogOrder('catalogOrder'),
  experienceModeSelection('experienceModeSelection'),
  essentialAddonSetup('essentialAddonSetup'),
  profileSelection('profileSelection'),
  licensesAttributions('licensesAttributions'),
  tmdbEntityBrowse('tmdbEntityBrowse'),
  folderDetail('folderDetail');

  const RoutePath(this.name);

  final String name;

  static RoutePath fromName(String name) => RoutePath.values.firstWhere(
        (r) => r.name == name,
        orElse: () => RoutePath.home,
      );
}

/// Arguments passed to a route builder.
///
/// Kept as a simple typed bag; each screen validates what it needs.
class RouteArgs {
  const RouteArgs({
    this.metaId,
    this.metaType,
    this.videoId,
    this.season,
    this.episode,
    this.streamUrl,
    this.streamTitle,
    this.catalogId,
    this.catalogName,
    this.addonId,
    this.addonType,
    this.genre,
    this.query,
    this.resumePositionMs,
    this.extra = const {},
  });

  final String? metaId;
  final String? metaType;
  final String? videoId;
  final int? season;
  final int? episode;
  final String? streamUrl;
  final String? streamTitle;
  final String? catalogId;
  final String? catalogName;
  final String? addonId;
  final String? addonType;
  final String? genre;
  final String? query;
  final int? resumePositionMs;
  final Map<String, dynamic> extra;
}
