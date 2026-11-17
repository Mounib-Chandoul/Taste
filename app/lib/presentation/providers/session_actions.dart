import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api.dart';
import '../../data/repositories/backend_music_repository.dart';
import '../app_router.dart';
import 'app_providers.dart';

const _serverKey = 'pixel_server';
const _tokenKey = 'pixel_token';
const _usernameKey = 'pixel_username';

String? _etagFrom(Map<String, dynamic>? library) {
  final version = library?['version'];
  if (version == null) return null;
  return version.toString();
}

Future<void> _clearPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
  } catch (_) {}
}

void _invalidateLibrary(WidgetRef ref) {
  ref.invalidate(currentUserProvider);
  ref.invalidate(artistsProvider);
  ref.invalidate(tracksProvider);
  ref.invalidate(playlistsProvider);
  ref.invalidate(recentlyPlayedProvider);
  ref.invalidate(madeForYouProvider);
}

BackendSession _installSession(
  WidgetRef ref, {
  required ServerApi api,
  required String username,
  required Map<String, dynamic> library,
  required List<Map<String, dynamic>> playlists,
}) {
  api.onUnauthorized = () => forceLogout(ref);
  final repository = BackendMusicRepository(
    api: api,
    library: library,
    username: username,
    playlists: playlists,
  );
  final session = BackendSession(
    api: api,
    repository: repository,
    username: username,
  );
  ref.read(backendSessionProvider.notifier).state = session;
  ref.read(pixelUsernameProvider.notifier).state = username;
  ref.read(pixelAuthProvider.notifier).state = true;
  _invalidateLibrary(ref);
  return session;
}

/// Persists a freshly authenticated session and primes the offline cache.
Future<BackendSession> saveSession(
  WidgetRef ref, {
  required ServerApi api,
  required String username,
  required Map<String, dynamic> library,
  required List<Map<String, dynamic>> playlists,
}) async {
  final session = _installSession(
    ref,
    api: api,
    username: username,
    library: library,
    playlists: playlists,
  );
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, api.base);
    await prefs.setString(_tokenKey, api.token ?? '');
    await prefs.setString(_usernameKey, username);
  } catch (_) {}
  try {
    await ref.read(libraryStoreProvider).saveLibrary(library);
  } catch (_) {}
  return session;
}

/// Restores a saved session, validating the token with a conditional library
/// fetch. Falls back to the cached library when the LAN server is unreachable.
Future<BackendSession?> restoreSession(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final server = prefs.getString(_serverKey);
  final token = prefs.getString(_tokenKey);
  final username = prefs.getString(_usernameKey) ?? 'listener';
  if (server == null || server.isEmpty || token == null || token.isEmpty) {
    return null;
  }

  final api = ServerApi(server)..token = token;
  api.onUnauthorized = () => forceLogout(ref);
  final store = ref.read(libraryStoreProvider);
  Map<String, dynamic>? cached;
  try {
    cached = await store.loadLibrary();
  } catch (_) {}

  try {
    final result = await api.libraryFetch(etag: _etagFrom(cached));
    final library = result.notModified ? cached : result.data;
    if (library == null) return null;

    List<Map<String, dynamic>> playlists = const [];
    try {
      playlists = await api.playlists();
    } catch (_) {}
    await store.saveLibrary(library);
    return _installSession(
      ref,
      api: api,
      username: username,
      library: library,
      playlists: playlists,
    );
  } on AuthException {
    await _clearPrefs();
    return null;
  } catch (_) {
    if (cached == null) return null;
    // Offline start: the cached library is still usable for browsing/playback.
    return _installSession(
      ref,
      api: api,
      username: username,
      library: cached,
      playlists: const [],
    );
  }
}

/// Revalidates the library in the background (304 is essentially free).
Future<void> syncLibrary(WidgetRef ref) async {
  final session = ref.read(backendSessionProvider);
  if (session == null) return;
  final store = ref.read(libraryStoreProvider);
  Map<String, dynamic>? cached;
  try {
    cached = await store.loadLibrary();
  } catch (_) {}
  try {
    final result = await session.api.libraryFetch(etag: _etagFrom(cached));
    if (result.notModified || result.data == null) return;
    session.repository.updateLibrary(result.data!);
    await store.saveLibrary(result.data!);
    _invalidateLibrary(ref);
  } on AuthException {
    // onUnauthorized already cleared the session; nothing else to do.
  } catch (_) {}
}

/// Removes only the saved credentials, without touching in-memory state.
Future<void> clearPersistedSession() => _clearPrefs();

/// Drops the local session. Used by both explicit logout and 401 responses.
Future<void> forceLogout(WidgetRef ref) async {
  await _clearPrefs();
  ref.read(backendSessionProvider.notifier).state = null;
  ref.read(pixelAuthProvider.notifier).state = false;
  ref.read(pixelUsernameProvider.notifier).state = 'listener';
  _invalidateLibrary(ref);
  appRouter.go('/login');
}

/// Explicit disconnect: revoke the token server-side before local cleanup.
Future<void> signOut(WidgetRef ref) async {
  final session = ref.read(backendSessionProvider);
  if (session != null) await session.api.logout();
  await forceLogout(ref);
}
