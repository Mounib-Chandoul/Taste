# Music Lab — Flutter client

Pixel-styled client for the Music Lab server. Runs on web, Android and desktop;
talks to the FastAPI backend over your LAN and caches the library locally.

## Highlights

- Responsive Pixel UI: bottom navigation on phones, navigation rail on wide screens.
- Library browsing, ranked server search, genres and random-track discovery.
- Playlists with add/remove/reorder, shuffle and repeat.
- Queue-first Now Playing screen with a live spectrum monitor, elapsed/remaining
  time tiles and a live clock. No cover photos or spinning artwork.
- Background playback and lock-screen controls on Android.
- Full-file offline downloads on Android; offline copies take priority over network.
- Session restore, 401 handling and logout. Blank Server field = demo/mock mode.

## Setup

```powershell
cd app
flutter pub get
flutter run                   # server must be running
flutter build web --release   # output in build/web
flutter build apk             # output in build/app/outputs/flutter-apk
```

On first launch, enter `http://<pc-ip>:4533` and the credentials from
`server/.env`. For phone testing over plain HTTP, the Android manifest already
enables cleartext traffic and the required foreground-service permissions.

## Notes

- `lib/main.dart` starts the Pixel app (`lib/pixel_main.dart`). The older
  Provider-based UI is preserved at `lib/legacy_main.dart`.
- `third_party/phosphor_flutter` is a patched local copy: upstream 2.1.0 subclasses
  `IconData`, which became final in Flutter 3.50. `pubspec.yaml` overrides the
  dependency with this copy.
- Fonts (Silkscreen, JetBrains Mono) are bundled — no runtime font downloads.
- Audio is streamed as the original file format. Web playback requires a server
  that accepts `?token=` on media URLs; the app sends both that and the bearer header.

## Checks

```powershell
flutter test
flutter analyze --no-fatal-infos
flutter build web --release
```

See the [root README](../README.md) for server setup and [music tagging tips](../server/MUSIC_SETUP.md).
