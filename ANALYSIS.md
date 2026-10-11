# Nuvio Feature Analysis (from NuvioTVSmart web + NuvioTV Android)

## Routes (from web router)
home, player, account, authQrSignIn, authSignIn, serverConnection, syncCode,
profileSelection, experienceModeSelection, essentialAddonSetup, detail, library,
search, discover, settings, debugConsole, trakt, supportersContributors,
licensesAttributions, plugin, plugins, catalogOrder, stream, castDetail,
catalogSeeAll, tmdbEntityBrowse, folderDetail

## Sidebar: Home, Search, Library, Settings (+Discover optional)

## Experience modes: modern | grid | classic (home layouts)

## Core domain models
- Meta (id, type movie/series, name, poster, background, description, releaseInfo,
  imdbRating, genres, runtime, cast, director, videos[] episodes)
- Stream (name, title, description, url, ytId, infoHash, fileIdx, externalUrl,
  behaviorHints, addonName, addonLogo, sourceProviderId, addonOrderIndex)
- CatalogRow (addon id, type, catalog id/name, items[])
- Addon (manifest: id, name, version, types[], catalogs[], resources[], background)
- WatchProgress (contentId, contentType, videoId, positionMs, durationMs, updatedAt)
  thresholds: started 2%, completed 90% (simkl 80%)
- Subtitle (id, lang, url, format)
- UserProfile, AuthState, ContentType

## Data sources
1. Stremio addons (manifest.json protocol): catalogs, meta, streams, subtitles
2. Nuvio JS plugins (repositories of JS scrapers, executed in JS engine)
   - Android uses QuickJS; scrapers have manifest + loadLinks
   - MAX 10 concurrent scrapers, 150 results, 120s timeout
3. Debrid: Torbox, Premiumize, Real-Debrid (device-code or API-key auth)
   capabilities: clientResolve, localTorrentCacheCheck, localTorrentResolve, cloudLibrary
4. Torrent/P2P: Tizen 5.5+ via EngineFS service; Android has full torrent engine
5. TMDB enrichment (metadata, images, episode enrichment)
6. Trakt + Simkl + MDBList tracking
7. Supabase (profiles, avatars, cloud library, member access)
8. IMDB ratings, IntroDB (skip intro), Parental guide, YouTube trailers

## Streams resolution flow
- Sources: addons (Stremio protocol) + plugins (JS scrapers) + debrid + p2p
- Ordering: group by source kind (addon/plugin), rank by addonOrderIndex
- AutoPlay modes: MANUAL | FIRST_STREAM | REGEX_MATCH
- AutoPlay source: ALL | INSTALLED_ADDONS_ONLY | ENABLED_PLUGINS_ONLY

## Player features
- Subtitles: embedded, addon-provided, external; ASS->VTT conversion; delay control
- Audio tracks: embedded + manifest-parsed (DASH)
- Skip intro (IntroDB), next episode overlay + autoplay
- Resume positions, post-play recommendations
- Pause overlay, buffering spinner, stream source switcher

## Home screen
- Hero carousel (backdrop + logo swap animations)
- Continue watching row (with watched toggling, hold menu)
- Next Up / airing episodes
- Catalog rows from addons (lazy image hydration, pagination)
- Grid layout mode alternative

## Design tokens (dark theme)
bg #0d0d0d, elevated #1a1a1a, card #222222, text #fff, secondary #b3b3b3,
tertiary #808080, focus #fff, focusBg #303030, border #333, error #cf6679
Font: Inter. TV safe gutter 32px, card radius 16px, card gap 14px,
button height 60px, control size 64px
Focus: scale(1.1) transform, 0.2s transitions

## Performance lessons (why web version is slow)
- DOM manipulation + CSS transitions on TV Chromium = jank
- Image hydration is manual/lazy due to memory
- Flutter advantage: Impeller/Skia rendering, const widgets, no DOM

## Tizen constraints (web version)
- P2P: Tizen 5.5+ only via EngineFS
- Plugins: Tizen 6.0+ only
- Flutter port: native code, no Chromium limits — but JS scrapers still need a JS engine
