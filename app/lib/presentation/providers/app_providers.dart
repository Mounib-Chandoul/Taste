import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../data/repositories/backend_music_repository.dart';
import '../../data/repositories/mock_music_repository.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/services/download_service.dart';
import '../../domain/audio/audio_player_service.dart';
import '../../domain/audio/just_audio_player_service.dart';
import '../../domain/audio/mock_audio_player_service.dart';
import '../../domain/audio/playback_source.dart';
import '../../store.dart';

class BackendSession {
  const BackendSession({
    required this.api,
    required this.repository,
    required this.username,
  });
  final ServerApi api;
  final BackendMusicRepository repository;
  final String username;
}

/// Real backend session (null = mock/offline demo mode).
final backendSessionProvider = StateProvider<BackendSession?>((ref) => null);

/// Platform cache for `/api/library` and the offline manifest.
final libraryStoreProvider = Provider<Store>((ref) => createStore());

/// Offline download manager. Null in demo mode (no server to download from).
final downloadServiceProvider = Provider<DownloadService?>((ref) {
  final session = ref.watch(backendSessionProvider);
  if (session == null) return null;
  return DownloadService(session.api, ref.watch(libraryStoreProvider));
});

/// Finished offline downloads, mapped for the Library screen.
final downloadsProvider = FutureProvider<List<DownloadedTrack>>((ref) async {
  final service = ref.watch(downloadServiceProvider);
  if (service == null) return const [];
  final items = await service.load();
  return items.values.toList()
    ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
});

/// Uses [BackendMusicRepository] when a backend session is active, else mock.
final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final session = ref.watch(backendSessionProvider);
  return session?.repository ?? const MockMusicRepository();
});

/// Uses [JustAudioPlayerService] with backend stream URLs when a backend
/// session is active, else [MockAudioPlayerService].
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final session = ref.watch(backendSessionProvider);
  final AudioPlayerService service;
  if (session != null) {
    service = JustAudioPlayerService(
      sourceResolver: (track) async {
        // A finished offline download always wins over the network stream.
        final downloads = ref.read(downloadServiceProvider);
        final realId = session.repository.realIdForPixelTrack(track.id);
        if (downloads != null && realId != null) {
          try {
            final localPath = await downloads.localPath(realId);
            if (localPath != null) {
              return PlaybackSource(
                uri: Uri.file(localPath),
                filePath: localPath,
                artUri: Uri.tryParse(
                  session.repository.coverUrlForPixelTrack(track.id),
                ),
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
              );
            }
          } catch (_) {}
        }
        return session.repository.playbackSourceForPixelTrack(track.id);
      },
    );
  } else {
    service = MockAudioPlayerService();
  }
  ref.onDispose(() => service.dispose());
  return service;
});

final audioSnapshotProvider = StreamProvider<AudioPlayerSnapshot>((ref) {
  final audio = ref.watch(audioPlayerServiceProvider);
  return audio.stream;
});

final currentUserProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(musicRepositoryProvider).getCurrentUser();
});

final artistsProvider = FutureProvider<List<Artist>>((ref) {
  return ref.watch(musicRepositoryProvider).getArtists();
});

final tracksProvider = FutureProvider<List<Track>>((ref) {
  return ref.watch(musicRepositoryProvider).getTracks();
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) {
  return ref.watch(musicRepositoryProvider).getPlaylists();
});

final recentlyPlayedProvider = FutureProvider<List<Track>>((ref) {
  return ref.watch(musicRepositoryProvider).getRecentlyPlayed();
});

final madeForYouProvider = FutureProvider<List<Playlist>>((ref) {
  return ref.watch(musicRepositoryProvider).getMadeForYou();
});

/// Debounced ranked search. Backend sessions use `/api/search` (FTS5 trigram
/// + BM25); demo mode filters the bundled mock catalogue locally.
final searchResultsProvider =
    FutureProvider.family<LibrarySearchResults, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return LibrarySearchResults.empty;
  final repo = ref.watch(musicRepositoryProvider);
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (cancelled) return LibrarySearchResults.empty;
  return repo.search(q);
});

/// Genres actually present in the connected library (empty in demo mode
/// unless the mock repository supplies them).
final genresProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(musicRepositoryProvider).genres();
});

/// A server-side random mix, used by the Home screen.
final randomTracksProvider = FutureProvider.family<List<Track>, int>((ref, limit) async {
  return ref.watch(musicRepositoryProvider).randomTracks(limit: limit);
});

/// Live accent color selection for the Settings accent picker.
final accentColorProvider = StateProvider<Color>((ref) => AppColors.dark.cyan);

/// Shell tab index (Home/Search/Library/Settings in full app; Home-focused now).
final shellTabProvider = StateProvider<int>((ref) => 0);

/// Search screen query (terminal input).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Mock auth state for the Pixel UI flow (splash/login -> shell).
final pixelAuthProvider = StateProvider<bool>((ref) => false);

/// Mock signed-in display name.
final pixelUsernameProvider = StateProvider<String>((ref) => 'listener');
