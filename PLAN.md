# NuvioTVFlutter — Master Implementation Plan

> **Project:** Nuvio — free open-source media app for Samsung Tizen TVs, rebuilt in Flutter.
> **Package:** `fyl.nuvio.nuvio_tv_flutter` · **App label:** `Nuvio` · **Target:** Tizen 6.0+ (TV profile)
> **Reference repos:** `NuvioTVSmart` (web/Tizen, feature source of truth for UI) · `NuvioTV` (Android TV, feature source of truth for capabilities)
> **Prime directive:** mimic the official UI/features 1:1 where the platform allows; take the Android feature set where the TV web build is limited; buttery-smooth animations (the official Tizen web build is not smooth — that's why this port exists); modular design, one class per responsibility; complete Dart test coverage per module.

---

## 0. Guiding principles

1. **Feature parity over code parity.** We copy *behavior and flow*, not JS structure. Where Flutter does it better (declarative UI, real focus system), we do it Flutter's way.
2. **One class, one responsibility.** Every file has exactly one primary class (or one tightly-cohesive enum/extension set). Screens are *thin* — they compose widgets and watch providers; logic lives in controllers/services.
3. **Test with the code.** Every module lands with its test file in the same increment. `dart test` green before the module counts as done.
4. **TV-first interaction.** Every screen must be fully operable by D-pad alone. Pointer/mouse is a bonus, never a requirement.
5. **Smoothness budget.** Any animation must run on the GPU (transform/opacity only). No per-frame `setState`. Lists use `builder` constructors. Images use `cacheWidth/cacheHeight`. Target: 60 fps focus traversal on a 2018 TV-class device.
6. **Graceful degradation.** Features gated on config (Supabase, Trakt, Simkl keys) hide themselves when unprovisioned — never crash, never show dead UI.

---

## 1. Architecture overview

```
lib/
├── main.dart                     # bootstrap: env, storage, runApp
├── app.dart                      # MaterialApp + theme + routes
│
├── core/                         # platform-agnostic infrastructure
│   ├── config/
│   │   └── app_config.dart           # compile-time env (Supabase, Trakt, Simkl keys)
│   ├── network/
│   │   ├── http_client.dart          # thin wrapper over package:http (timeouts, retries, headers)
│   │   └── api_exception.dart        # typed errors (network, http, parse)
│   ├── storage/
│   │   ├── local_store.dart          # typed key-value store over shared_preferences
│   │   ├── profile_scoped_store.dart # per-profile namespacing wrapper
│   │   └── storage_keys.dart         # all keys in one place
│   ├── theme/
│   │   ├── theme.dart                # NuvioColors, NuvioSpacing, buildNuvioTheme  ✅ done
│   │   ├── theme_manager.dart        # custom accent/theme persistence (customThemePalette port)
│   │   └── poster_shape.dart         # poster/landscape/square card geometry
│   ├── navigation/
│   │   ├── dpad.dart                 # NuvioKeyAction, throttle, FocusScale            ✅ done
│   │   ├── route_paths.dart          # typed route names (27 routes from official router)
│   │   └── router.dart               # GoRouter-style map + back-stack semantics
│   ├── player/
│   │   ├── player_controller.dart    # playback state machine (idle/loading/playing/paused/error/ended)
│   │   ├── player_settings.dart      # autoplay mode, subtitles prefs, skip interval
│   │   ├── subtitle_parser.dart      # SRT/VTT parsing + ASS→cue conversion
│   │   └── track_selector.dart       # audio/subtitle track selection logic
│   ├── p2p/
│   │   ├── torrent_engine.dart       # abstract torrent interface
│   │   ├── torrent_settings.dart     # p2pEnabled, enableUpload, hideTorrentStats
│   │   └── torrent_progress.dart     # download state model
│   ├── plugin/
│   │   ├── plugin_models.dart        # PluginRepository, ScraperInfo, PluginState
│   │   ├── plugin_store.dart         # persistence (profile-scoped)
│   │   └── scraper_runner.dart       # JS scraper execution boundary (see §7)
│   ├── debrid/
│   │   ├── debrid_provider.dart      # provider descriptors (Torbox/Premiumize/RealDebrid)
│   │   ├── debrid_auth_service.dart  # device-code + API-key flows
│   │   └── debrid_resolver.dart      # cache-check + resolve to direct URL
│   ├── tmdb/
│   │   ├── tmdb_service.dart         # enrichment: images, logos, episode data
│   │   └── tmdb_image_urls.dart      # poster/backdrop/logo URL builder
│   ├── tracking/
│   │   ├── trakt_service.dart        # OAuth device flow, scrobble, watchlist
│   │   ├── simkl_service.dart        # OAuth + scrobble
│   │   └── mdblist_service.dart      # ratings + lists
│   └── util/
│       ├── result.dart               # Ok/Err result type
│       ├── formatters.dart           # duration/bytes/date formatting
│       └── id_utils.dart             # imdb/tmdb id helpers, video id keys
│
├── domain/                       # pure models + repository contracts (no Flutter imports)
│   ├── models/                                                              ✅ all done
│   │   ├── content_type.dart             ✅
│   │   ├── meta.dart                     ✅ (Meta + MetaPreview)
│   │   ├── video.dart                    ✅
│   │   ├── stream.dart                   ✅ (Stream, Subtitle, StreamRequest, StreamOriginKind)
│   │   ├── addon.dart                    ✅ (Addon, AddonCatalog, AddonExtra, AddonResource)
│   │   ├── catalog_row.dart              ✅
│   │   ├── watch_progress.dart           ✅ (WatchProgress, WatchedItem)
│   │   ├── user_profile.dart             ✅ (UserProfile, ExperienceMode)
│   │   ├── plugin.dart                   # PluginRepository, Scraper, PluginState
│   │   ├── debrid.dart                   # DebridProvider, DebridAccount, DebridSettings
│   │   └── library_item.dart             # SavedLibraryItem, CollectionFolder
│   └── repositories/
│       ├── addon_repository.dart         # manifest CRUD, enabled state
│       ├── catalog_repository.dart       # fetch + merge catalog rows
│       ├── meta_repository.dart          # meta detail + enrichment
│       ├── stream_repository.dart        # resolve streams from all sources
│       ├── watch_progress_repository.dart# continue-watching state
│       ├── library_repository.dart       # saved items, collections
│       └── subtitle_repository.dart      # addon subtitles + external
│
├── data/                         # implementations of domain repositories
│   ├── local/
│   │   ├── addon_store.dart
│   │   ├── watch_progress_store.dart
│   │   ├── watched_items_store.dart
│   │   ├── saved_library_store.dart
│   │   ├── player_settings_store.dart
│   │   ├── plugin_store_impl.dart
│   │   ├── debrid_settings_store.dart
│   │   ├── search_history_store.dart
│   │   └── profile_store.dart
│   ├── remote/
│   │   ├── addon_api.dart            # GET {url}/manifest.json, /catalog/..., /stream/..., /subtitles/...
│   │   ├── tmdb_api.dart
│   │   ├── trakt_api.dart
│   │   ├── simkl_api.dart
│   │   ├── mdblist_api.dart
│   │   └── debrid_api.dart           # per-provider endpoints
│   └── repositories/                 # concrete impls wiring local+remote
│
├── state/                        # Riverpod providers (app-wide state)
│   ├── profile_provider.dart
│   ├── addon_provider.dart
│   ├── catalog_provider.dart
│   ├── watch_progress_provider.dart
│   ├── settings_provider.dart
│   └── stream_provider.dart
│
└── ui/
    ├── app_shell.dart                # sidebar + tab switching                        ✅ done
    ├── components/
    │   ├── poster_card.dart          # focus-scale poster, progress bar, badges
    │   ├── catalog_row_widget.dart   # horizontal lazy list with edge fade
    │   ├── hero_carousel.dart        # backdrop+logo crossfade, autoplay timer
    │   ├── continue_watching_row.dart
    │   ├── nuvio_dialog.dart         # TV-styled modal (options, text input)
    │   ├── loading_indicator.dart    # branded spinner
    │   ├── sidebar.dart              # extracted from app_shell
    │   └── watched_badge.dart
    ├── navigation/
    │   └── focus_traversal.dart      # helpers for grid/row focus order
    └── screens/
        ├── home/                     # hero + rows + continue watching
        ├── detail/                   # meta details, episodes, stream chooser
        ├── player/                   # full playback UI
        ├── library/                  # saved + collections + watched
        ├── search/                   # query + history + addon search
        ├── discover/                 # TMDB browse
        ├── catalog/                  # see-all grid
        ├── settings/                 # all settings sections
        ├── plugin/                   # plugin repos + scrapers
        ├── stream/                   # stream picker screen
        └── onboarding/               # experience mode + essential addons
```

**State management:** Riverpod 2 (`Notifier`/`AsyncNotifier`). No global singletons; everything injectable for tests.

**Data flow:** `UI → provider → repository (domain iface) → data impl → API/store`. Repositories return `Future<Result<T>>`; providers expose `AsyncValue<T>` to widgets.

---

## 2. Increment plan (each = one PR-sized unit, code + tests together)

### INC-1 · Foundation  ✅ (partially done)
- [x] Project scaffold, Tizen manifest (`fyl.nuvio.nuvio_tv_flutter`, label "Nuvio", api 6.0)
- [x] pubspec deps: riverpod, http, shared_preferences, video_player, video_player_tizen, intl, collection
- [x] Domain models: ContentType, Meta/MetaPreview, Video, Stream/Subtitle/StreamRequest, Addon family, CatalogRow, WatchProgress/WatchedItem, UserProfile/ExperienceMode
- [x] Theme tokens + ThemeData builder
- [x] D-pad layer: key map, repeat throttle, FocusScale
- [x] AppShell: sidebar (auto-collapse) + tab switch
- [x] TPK builds (7.7 MB)
- [ ] `Result<T>` + `ApiException` + `HttpClient` wrapper + tests
- [ ] `LocalStore` + `ProfileScopedStore` + `StorageKeys` + tests
- [ ] Route paths enum + typed router + tests
- [ ] `main.dart` bootstrap: storage init, provider scope, immersive mode

### INC-2 · Addon engine (Stremio protocol)
- [ ] `AddonApi`: manifest / catalog / meta / stream / subtitles GET builders
- [ ] `AddonRepository` impl: install (URL → manifest), enable/disable, order, remove
- [ ] `CatalogRepository`: parallel fetch across enabled addons, merge + order rows, genre extras, per-row pagination (`/catalog/.../skip=`)
- [ ] `MetaRepository`: detail fetch with addon fallback chain (first addon that answers wins), parse videos
- [ ] `StreamRepository` (addon leg only): `/stream/{type}/{id}.json` merge, dedupe by url+infoHash
- [ ] `SubtitleRepository`: addon-provided subtitles
- [ ] Unit tests: JSON parsing fixtures (real manifest shapes), repository logic with fake HTTP
- [ ] **Deliverable:** settings screen can add/remove addons; home shows real catalog rows from a public addon (e.g. Cinemeta)

### INC-3 · Home screen (the showpiece)
- [ ] `HeroCarousel`: backdrop + logo crossfade (AnimatedSwitcher, 400 ms), auto-advance 8 s, D-pad left/right, focus pause
- [ ] `ContinueWatchingRow`: from WatchProgress store, progress bar overlay, hold-to-remove dialog (long-press OK)
- [ ] `NextUpRow`: next unwatched episode per in-progress series
- [ ] `CatalogRowWidget`: horizontal `ListView.builder`, edge fade, lazy poster decode (`cacheWidth`), pagination on near-end
- [ ] `PosterCard`: focus scale 1.1 (GPU-only), poster/landscape shapes, badges (imdb rating, quality, watched)
- [ ] `HomeScreen`: composes rows; modern layout; skeleton loaders; error rows with retry
- [ ] Focus traversal: row-to-row vertical, first-focus restore on back
- [ ] Widget tests: row rendering, focus movement, pagination trigger
- [ ] **Deliverable:** home looks + navigates like official modern layout with real Cinemeta data

### INC-4 · Detail + stream chooser
- [ ] `DetailScreen`: hero (backdrop, logo, description, imdb badge), cast row, more-like-this row
- [ ] Series: season selector (D-pad), episode list with watched markers + progress, episode play
- [ ] `StreamRepository` full merge: addons + debrid + plugins (plugin leg stubbed until INC-7)
- [ ] `StreamOrdering`: group by origin kind, rank by addonOrderIndex, quality badges (4K/1080/720 parse from name)
- [ ] `StreamPickerScreen` (route `stream`): grouped list, source chips, autoplay selection (MANUAL/FIRST_STREAM/REGEX_MATCH port)
- [ ] `StreamAutoPlaySelector`: exact port of web logic + tests
- [ ] Widget tests: season/episode navigation, stream grouping
- [ ] **Deliverable:** pick any title → see real streams → choose one

### INC-5 · Player
- [ ] `PlayerController` (state machine): idle→loading→playing⇄paused→ended|error; position ticker (1 Hz, not per-frame)
- [ ] `video_player_tizen` integration: init, seek, speed, surface lifecycle
- [ ] `PlayerScreen`: chrome auto-hide 3 s on D-pad idle, show on any key
- [ ] Transport: OK=play/pause, left/right=±10 s (configurable skip interval), up/down=chrome, back=exit w/ confirm if >2 min watched
- [ ] Progress bar + buffered bar, time labels, seek preview
- [ ] Subtitles: SRT/VTT parse → cues; external URL load; delay control (±100 ms); size/position settings; embedded track select
- [ ] Audio track selection (from manifest/behaviorHints when exposed)
- [ ] Resume: save position every 5 s + on pause/exit; resume prompt if >2% and <90%
- [ ] Next-episode overlay (last 30 s) + autoplay next; post-play recommendations row
- [ ] Skip-intro button (IntroDB API when provisioned)
- [ ] Widget tests: controller transitions, subtitle cue timing, resume logic
- [ ] **Deliverable:** play a real MP4/HLS stream end-to-end with subtitles

### INC-6 · Library, search, discover
- [ ] `LibraryScreen`: tabs (Saved | Watched | Collections), grid + list layouts, sort (recently watched/added/name), remove/hold menu
- [ ] `SavedLibraryStore` + `LibraryRepository` + tests
- [ ] `SearchScreen`: on-screen keyboard (D-pad grid), history chips, addon search (`catalog/{id}/{type}/search={query}`), debounced 300 ms, results grid
- [ ] `DiscoverScreen`: TMDB trending/popular/genres browse (when TMDB key provisioned; hidden otherwise)
- [ ] `CatalogSeeAllScreen`: full grid for any catalog row, pagination
- [ ] Widget tests: search debounce, history, library tabs
- [ ] **Deliverable:** full browse→search→library loop

### INC-7 · Plugin system (JS scrapers)
- [ ] `PluginModels`: PluginRepository (url, type: nuvio-js|cs3-external), Scraper (id, manifest, code), PluginState (max 20 repos, dedupe)
- [ ] `PluginStore`: profile-scoped persistence + sync-backoff port
- [ ] `ScraperRunner`: **decision point** — options:
  - (a) Bundle `flutter_js` (QuickJS) and execute Nuvio JS scrapers natively → full parity
  - (b) Tizen service app runs Node (like official EngineFS/PluginService) → heavy
  - **Chosen: (a)** flutter_js + fetch polyfill; scrapers are network-bound (10 concurrent, 150 results, 120 s timeout — port Android's constants)
- [ ] `PluginManager`: add repo (parse repo index), enable/disable scrapers, execute `loadLinks(type, imdbId, season, episode)` → `List<Stream>`
- [ ] Safety: response size cap 5 MB, timeout, no eval of non-scraper code, hash-verified updates
- [ ] `PluginsScreen` + `PluginScreen` + `CatalogOrderScreen` UI
- [ ] Tests: plugin state normalization (port web tests), fake scraper execution
- [ ] **Deliverable:** add a Nuvio plugin repo URL → scrapers appear → contribute streams

### INC-8 · Debrid integration
- [ ] `DebridProvider` descriptors (Torbox, Premiumize, Real-Debrid) — port capability matrix
- [ ] Auth: device-code flow (poll endpoint) + API-key entry; masked display
- [ ] `DebridResolver`: for torrent streams → cache-check → resolve to direct URL; for direct streams → unrestrict
- [ ] Badge + ordering: debrid streams get priority badge, sort above p2p
- [ ] Settings UI: accounts section, per-provider status, logout
- [ ] Tests: auth state machine, cache-check decision logic (with fake API)
- [ ] **Deliverable:** connect Real-Debrid → torrent streams resolve to instant direct URLs

### INC-9 · Tracking (Trakt / Simkl / MDBList)
- [ ] Trakt: OAuth device flow, scrobble (start/pause/stop at thresholds), watchlist add/remove, history sync
- [ ] Simkl: OAuth, scrobble (80% completion), watchlist
- [ ] MDBList: API key, ratings enrichment on detail screen
- [ ] Settings sections per service (port `settingsIntegrationDetail*` flows)
- [ ] Tests: scrobble threshold logic, token refresh
- [ ] **Deliverable:** watch something → appears in Trakt history

### INC-10 · Profiles + cloud (Supabase, gated)
- [ ] `ProfileManager`: local profiles (avatar colors, initial), profile switcher on sidebar avatar
- [ ] Per-profile scoping of: addons, plugins, progress, library, settings (ProfileScopedStore everywhere)
- [ ] Supabase (only when keys provisioned): device login (QR → nuvio.tv/tv-login), avatar, cloud library sync, member access
- [ ] Tests: profile isolation
- [ ] **Deliverable:** multiple profiles, each with own everything

### INC-11 · Settings (complete)
- [ ] Sections ported from official: General (language, experience mode), Layout (poster shape, card depth, row order), Playback (autoplay, skip interval, resume behavior), Audio (passthrough, compatibility), Subtitles (style: size/color/opacity/delay), P2P (enable, upload, hide stats), Plugins, Integrations (Trakt/Simkl/MDBList/Debrid), Advanced (diagnostics, licenses)
- [ ] Theme settings: accent color picker → `ThemeManager` (custom palette mixing port)
- [ ] Tests: settings round-trip persistence
- [ ] **Deliverable:** settings screen at feature parity

### INC-12 · Onboarding + polish
- [ ] `ExperienceModeSelectionScreen` (modern/grid/classic)
- [ ] `EssentialAddonSetupScreen`: suggested addon list, one-OK install
- [ ] App icon (Nuvio brand), splash, update prompt banner
- [ ] Empty states + error states for every screen (TV-styled dialogs)
- [ ] Performance pass: profile dev mode on Tizen build, verify 60 fps focus, image memory budget
- [ ] **Deliverable:** fresh-install experience identical in spirit to official

### INC-13 · Full test suite completion
- [ ] `dart test` coverage: every repository (fake HTTP), every store (round-trip), every controller (state machine), stream ordering/autoplay (port web test cases), subtitle parser (SRT/VTT/ASS fixtures)
- [ ] Widget tests: every screen renders with sample data, D-pad traversal on home/detail/player
- [ ] Golden tests: poster card, hero, sidebar (light/dark accent)
- [ ] Target: analyzer zero warnings, all tests green in CI-style run

### INC-14 · Release hardening
- [ ] Signing: Samsung distributor cert flow documented (needs TV DUID + Seller Portal account) — dev-signed TPK until then
- [ ] `--release` build size audit, startup time (target < 3 s to interactive home)
- [ ] Crash-safe storage (atomic writes), low-memory image cache eviction
- [ ] Version + changelog, README, build docs

---

## 3. Key algorithm ports (exact sources)

| Algorithm | Source file (web) | Dart target | Tests |
|---|---|---|---|
| Watch progress thresholds | `domain/model/watchProgress.js` | `WatchProgress` ✅ | unit ✅ |
| Stream ordering (addon ranks) | `core/streams/streamOrdering.js` | `StreamOrdering` | port fixtures |
| Auto-play selection | `core/streams/streamAutoPlaySelector.js` | `StreamAutoPlaySelector` | port all modes |
| Continue-watching windows | `ui/screens/home/continueWatchingRenderWindow.js` | `ContinueWatchingPolicy` | unit |
| Next-up candidate resolution | `nextUpCandidateResolver.js` + `nextUpEpisodeAnchor.js` | `NextUpResolver` | unit |
| Plugin state normalization | `pluginModelsHelpers-03-normalize-plugin-state.js` | `PluginState.normalize` | port tests |
| Custom theme palette mixing | `core/util/customThemeColors.js` | `ThemeManager` | color math tests |
| Quality detection from stream name | `metaDetailsScreenHelpers-04-detect-quality.js` | `QualityDetector` | unit |
| Subtitle language aliases | `player/subtitleLanguageAliases.js` | `SubtitleAliases` | unit |
| D-pad repeat throttle | `navigation/dpadRepeatThrottle.js` | `DpadRepeatThrottle` ✅ | widget |

---

## 4. Performance contract (the reason this port exists)

1. **Focus movement:** `AnimatedScale` + `AnimatedContainer` (transform/opacity only) — GPU composited, no layout thrash.
2. **Lists:** `ListView.builder` / `GridView.builder` everywhere; `itemExtent` where fixed; `addAutomaticKeepAlives: false`, `cacheExtent` tuned (≈800 px).
3. **Images:** `Image.network` with `cacheWidth` sized to the card (poster ≈ 352 px decode for 176 pt display); `gaplessPlayback: true`; evict on memory pressure.
4. **No per-frame setState:** position updates via 1 Hz ticker + `ValueListenable`; progress bars are `AnimatedBuilder` on a `ValueNotifier`.
5. **Startup:** lazy provider init; home shows skeleton instantly, data streams in.
6. **Budget:** focus traversal ≤ 1 dropped frame on Tizen 6.5 hardware profile; cold start ≤ 3 s.

---

## 5. Testing strategy

- **Unit:** models (JSON round-trip), repositories (fake `HttpClient`), controllers (state machines), algorithm ports (fixtures from JS tests).
- **Widget:** screens render with `ProviderScope(overrides: [...])` fake repos; D-pad traversal via `tester.sendKeyEvent`.
- **Golden:** poster card, hero, sidebar, stream row — 1080p logical size.
- **Fixtures:** real addon manifest JSON (Cinemeta), real stream response shapes, SRT/VTT/ASS subtitle samples — checked into `test/fixtures/`.
- Every INC lands green: `dart analyze` (0 issues) + `flutter test` (all pass) before moving on.

---

## 6. Risks & decisions log

| Decision / risk | Call |
|---|---|
| JS scrapers on Tizen | flutter_js (QuickJS) — network-bound scrapers, no DOM needed |
| DRM (Widevine) | video_player_videohole path deferred; standard streams first (INC-5). DRM flagged INC-15 candidate |
| P2P torrent playback | Tizen 6+ native torrent engine is a large lift; debrid-first (INC-8) covers most usage; native P2P = INC-15 candidate |
| Emulator testing | Blocked on host KVM permission; all verification via build + analyzer + tests until a TV/emulator is reachable |
| Signing | Dev (default) cert now; Samsung distributor cert requires TV DUID — document in INC-14 |
| YouTube trailers | Play via embedded player URL; proxy required on web version — Flutter may open directly; verify on device |

---

## 7. Out of scope (v1)

- LG webOS build (separate target, same codebase possible later)
- Cast screen (route exists in official; needs receiver hardware to test)
- Self-hosted mediaserver (Emby) integration
- Dolby Vision / HDR10+ metadata processing (Android-only native paths)
