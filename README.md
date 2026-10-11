# Nuvio TV — Flutter for Tizen

A free, open-source media app for Samsung Tizen TVs (2018+), rebuilt in
Flutter from the official [Nuvio TV web client](https://github.com/NuvioMedia/NuvioTVSmart).

**This is a client for the real Nuvio service** — existing Nuvio users pair
their TV and get their profiles, cloud library and watch progress synced from
the Nuvio backend. No separate account needed.

## Why Flutter?

The official Tizen build is a web app running on TV Chromium (2018 TVs ship
Chromium 56). DOM manipulation + CSS transitions on that baseline = jank.
Flutter renders through Impeller/Skia directly to the GPU, so focus movement,
hero transitions and list scrolling stay smooth even on older hardware.

## Features

- **Addon engine** — full Stremio protocol: install addons by URL, catalogs,
  meta, streams, subtitles
- **Plugin system** — community JS scrapers run in a sandboxed QuickJS engine
  (10 concurrent, 150 results, 120s timeout)
- **Debrid** — Torbox, Premiumize, Real-Debrid: torrent streams resolve to
  instant premium links
- **Player** — D-pad native (OK=play/pause, ±10s skip), auto-hiding chrome,
  resume positions, next-episode auto-play, subtitles
- **More Like This** — Trakt related titles (personalized) with TMDB fallback,
  on the detail page AND after playback
- **Tracking** — Trakt + Simkl device-code auth, scrobbling at official
  thresholds; MDBList ratings
- **Search** — TV keyboard, history, addon search
- **Library** — saved, watched, collections with progress bars
- **Account** — pair via nuvio.tv/tv-login (QR/code), session persists

## Building

### Prerequisites (in the flutter-dev container)

- Flutter 3.47.7 (git clone, Tizen-compatible)
- flutter-tizen tool (`/home/dev/flutter-tizen`)
- Tizen Studio CLI 10.0 + TV 9.0 emulator platform (`/home/dev/tizen-studio`)
- .NET 8 SDK (Tizen runner builds)

### Build a TPK

```bash
cd /home/dev/nuvio_tv_flutter
export PATH=/home/dev/flutter-tizen/bin:$PATH
export TIZEN_SDK=/home/dev/tizen-studio
export FLUTTER_TIZEN_NO_SIGNING=1   # dev signing (default certs)
flutter-tizen build tpk
# -> build/tizen/tpk/fyl.nuvio.nuvio_tv_flutter-1.0.0.tpk
```

### Install on a real TV

1. Enable Developer Mode on the TV (Settings → General → System Manager)
2. Create a Samsung certificate registered with your TV's DUID
   (Samsung Seller Portal / Certificate Manager)
3. Sign the TPK with that profile (remove `FLUTTER_TIZEN_NO_SIGNING`)
4. `tizen install -s <TV_IP> --name Nuvio tpk/...`

### Compile-time config

The Nuvio backend config ships via `--dart-define` (same values the official
clients use):

```bash
flutter-tizen build tpk \
  --dart-define=NUVIO_SUPABASE_URL=<backend-url> \
  --dart-define=NUVIO_SUPABASE_ANON_KEY=<publishable-key> \
  --dart-define=NUVIO_TRAKT_CLIENT_ID=<trakt-client-id> \
  --dart-define=NUVIO_SIMKL_CLIENT_ID=<simkl-client-id>
```

Features hide themselves gracefully when a key isn't provisioned.

## Architecture

```
lib/
├── core/       config, network (retry/timeout), storage, theme,
│               navigation (D-pad), player, p2p, plugin, debrid,
│               tmdb, tracking, util
├── domain/     pure models + repository interfaces (no Flutter imports)
├── data/       local stores + remote APIs + repository implementations
├── state/      Riverpod controllers (home, detail, library, settings, auth)
└── ui/         app shell + components + screens (11 screens)
```

One class per responsibility. Screens are thin — they compose widgets and
watch providers; logic lives in controllers/services. See `PLAN.md` for the
full increment-by-increment plan and `ANALYSIS.md` for the feature analysis
of the official clients.

## Testing

```bash
flutter test          # 187 tests, all green
dart analyze lib      # zero issues
```

Every module lands with its tests: unit (fake HTTP), widget (D-pad
traversal), algorithm ports with fixtures from the official JS tests.

## Performance contract

- GPU-only animations (transform/opacity) — no layout thrash
- `ListView.builder` everywhere, `cacheWidth` image decoding
- 1 Hz position ticker in the player (no per-frame rebuilds)
- Cold start < 3 s, focus traversal at 60 fps on Tizen 6.5 hardware

## License

Same as the official Nuvio clients (see LICENSE).
