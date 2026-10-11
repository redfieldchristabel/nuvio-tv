/// Central configuration for external services.
///
/// Values mirror the official Nuvio clients' config (js/config.js on the web
/// client). Empty strings mean the integration is not provisioned on this
/// build; the corresponding feature stays hidden instead of erroring.
class AppConfig {
  const AppConfig._();

  // --- Supabase (profiles, cloud library, member access) ---
  static const String supabaseUrl = String.fromEnvironment(
    'NUVIO_SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'NUVIO_SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // --- Device login (TV -> web pairing) ---
  static const String tvLoginWebBaseUrl = 'https://nuvio.tv/tv-login';
  static const String deviceLoginWebBaseUrl = 'https://nuvio.tv/link';

  // --- Metadata enrichment ---
  static const String parentalGuideApiUrl = 'https://api.tiffara.com/';
  static const String introDbApiUrl = 'https://api.introdb.app/';
  static const String mdbListApiBaseUrl = 'https://api.mdblist.com/';
  static const String imdbRatingsApiBaseUrl = String.fromEnvironment(
    'NUVIO_IMDB_RATINGS_API',
    defaultValue: '',
  );

  // --- Tracking ---
  static const String traktApiUrl = 'https://api.trakt.tv/';
  static const String traktRedirectUri = 'urn:ietf:wg:oauth:2.0:oob';
  static const String traktClientId = String.fromEnvironment(
    'NUVIO_TRAKT_CLIENT_ID',
    defaultValue: '',
  );
  static const String traktClientSecret = String.fromEnvironment(
    'NUVIO_TRAKT_CLIENT_SECRET',
    defaultValue: '',
  );
  static const String simklApiUrl = 'https://api.simkl.com';
  static const String simklClientId = String.fromEnvironment(
    'NUVIO_SIMKL_CLIENT_ID',
    defaultValue: '',
  );

  // --- Supporters ---
  static const String supportersApiBaseUrl = 'https://nuvio.tv/';
  static const String supportUrl = 'https://nuvio.tv/support';

  /// Whether cloud-backed features (profiles, cloud library) are provisioned.
  static bool get cloudEnabled => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether Trakt integration is provisioned.
  static bool get traktEnabled => traktClientId.isNotEmpty;

  /// Whether Simkl integration is provisioned.
  static bool get simklEnabled => simklClientId.isNotEmpty;
}
