/// Central configuration for external services.
///
/// Values mirror the official Nuvio clients' config (js/config.js on the web
/// client). Empty strings mean the integration is not provisioned on this
/// build; the corresponding feature stays hidden instead of erroring.
class AppConfig {
  const AppConfig._();

  // --- Nuvio backend (the REAL Nuvio service — this app is a client.
  //     Existing Nuvio users log in and their profiles/library/sync come
  //     from Nuvio's own backend. Same config the official clients use.) ---
  static const String supabaseUrl = String.fromEnvironment(
    'NUVIO_SUPABASE_URL',
    defaultValue: 'https://api.nuvio.tv',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'NUVIO_SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzgxNTIxMzQ2LCJleHAiOjE5MzkyMDEzNDZ9.tmQaj682pwzehpqlgCDMnySOqiUvpgRbrE43T4VJpDI',
  );
  static const String supabaseFallbackUrl = String.fromEnvironment(
    'NUVIO_SUPABASE_FALLBACK_URL',
    defaultValue: 'https://api-two.nuvioapp.space',
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
    defaultValue:
        '5783db7c46a5b22f072d4b224f9bd7dc2cbaba66dbe3515d1feb59e3ca72394c',
  );
  static const String traktClientSecret = String.fromEnvironment(
    'NUVIO_TRAKT_CLIENT_SECRET',
    defaultValue:
        'bf6e7561dafee902f5a2a67d2b31feac1563632f331f3958c978aff6389ea384',
  );
  static const String simklApiUrl = 'https://api.simkl.com';
  static const String simklClientId = String.fromEnvironment(
    'NUVIO_SIMKL_CLIENT_ID',
    defaultValue:
        'dc20e0db975583b15096267cee79cd23b1f56d4bd301ce3c51e4a96a49c834a6',
  );

  // --- TMDB ---
  static const String tmdbApiKey = String.fromEnvironment(
    'NUVIO_TMDB_API_KEY',
    defaultValue: '01926d2187b6a5d861eefc750e9df3e3',
  );

  // --- Supporters ---
  static const String supportersApiBaseUrl = 'https://nuvio.tv/';
  static const String supportUrl = 'https://nuvio.tv/support';

  /// Whether the Nuvio backend is configured (login + sync available).
  static bool get backendConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether Trakt integration is provisioned.
  static bool get traktEnabled => traktClientId.isNotEmpty;

  /// Whether Simkl integration is provisioned.
  static bool get simklEnabled => simklClientId.isNotEmpty;
}
