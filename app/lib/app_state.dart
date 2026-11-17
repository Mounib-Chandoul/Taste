import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'store.dart';

enum DownloadPhase { idle, downloading, done }

class DownloadInfo {
  DownloadInfo({
    required this.phase,
    this.progress = 0,
    required this.path,
    this.size = 0,
  });
  final DownloadPhase phase;
  final double progress; // 0..1
  final String path;
  final int size; // bytes (0 until done)
}

/// Global app state: connection, library cache, offline downloads.
class AppState extends ChangeNotifier {
  final Store _store = createStore();
  ServerApi? _api;

  bool loggedIn = false;
  String? serverUrl;
  String? username;

  List<Album> albums = [];
  List<Track> tracks = [];
  Map<int, Album> albumById = {};
  Map<int, List<Track>> tracksByAlbum = {};
  Map<int, Track> tracksById = {};
  List<Artist> artists = [];
  List<Track> allTracks = [];
  List<Playlist> playlists = [];

  final Map<int, DownloadInfo> _downloads = {};
  final Set<int> _activeDownloads = {};
  bool syncing = false;
  String? syncError; // last library sync failure, if any
  bool serverReachable = true; // optimistic; flips false on sync failure

  ServerApi get api {
    final a = _api;
    if (a == null) {
      throw StateError("Not connected - call connect() first");
    }
    return a;
  }

  bool get canDownload => _store.supportsDownloads;

  // ------------------------------------------------------------- startup

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString("serverUrl");
    username = prefs.getString("username");
    final token = prefs.getString("token");
    if (serverUrl != null && token != null && serverUrl!.isNotEmpty) {
      _api = ServerApi(serverUrl!)..token = token;
      loggedIn = true;
    }
    await _loadCaches();
    notifyListeners();
    // If we have saved credentials and a cached library, refresh in the
    // background so the app stays usable even when the PC/server is offline.
    if (loggedIn && albums.isNotEmpty) {
      // ignore: unawaited_futures
      syncLibrary().catchError((_) {});
    }
  }

  Future<void> _loadCaches() async {
    final lib = await _store.loadLibrary();
    if (lib != null) _applyLibrary(lib);
    final dl = await _store.loadDownloads();
    _downloads.clear();
    dl.forEach((key, value) {
      final id = int.tryParse(key);
      if (id != null && value is Map && value["path"] != null) {
        _downloads[id] = DownloadInfo(
          phase: DownloadPhase.done,
          path: value["path"] as String,
          size: (value["size"] as num?)?.toInt() ?? 0,
        );
      }
    });
  }

  // ------------------------------------------------------------- connect

  Future<void> connect({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final api = ServerApi(serverUrl);
    final token = await api.login(username, password);

    final prefs = await SharedPreferences.getInstance();
    final oldServer = prefs.getString("serverUrl");
    final changed = oldServer != null && oldServer != api.base;

    _api = api;
    this.serverUrl = api.base;
    this.username = username;
    loggedIn = true;

    await prefs.setString("serverUrl", api.base);
    await prefs.setString("token", token);
    await prefs.setString("username", username);

    if (changed) await _store.clear(); // downloads belong to the old server
    await _loadCaches();
    notifyListeners();
    try {
      await syncLibrary();
    } catch (_) {
      // Login succeeded and the library cache (if any) is loaded; let the
      // user proceed even if the first sync hiccups.
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    loggedIn = false;
    notifyListeners();
  }

  // ------------------------------------------------------------- library

  Future<void> syncLibrary() async {
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final lib = await api.library();
      _applyLibrary(lib);
      await _store.saveLibrary(lib);
      try {
        await refreshPlaylists();
      } catch (_) {
        // playlists are optional; library sync already succeeded
      }
      serverReachable = true;
    } on AuthException {
      // Token expired or revoked - require a fresh login.
      syncError = "Session expired";
      serverReachable = false;
      await logout();
      rethrow;
    } catch (e) {
      syncError = e.toString();
      serverReachable = false;
      rethrow;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> refreshPlaylists() async {
    final raw = await api.playlists();
    playlists = raw.map((j) => Playlist.fromJson(j)).toList();
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    await api.createPlaylist(name);
    await refreshPlaylists();
  }

  Future<void> renamePlaylist(int id, String name) async {
    await api.renamePlaylist(id, name);
    await refreshPlaylists();
  }

  Future<void> deletePlaylist(int id) async {
    await api.deletePlaylist(id);
    await refreshPlaylists();
  }

  Future<void> addToPlaylist(int playlistId, int trackId) async {
    await api.addToPlaylist(playlistId, trackId);
    await refreshPlaylists();
  }

  Future<void> removeFromPlaylist(int playlistId, int trackId) async {
    await api.removeFromPlaylist(playlistId, trackId);
    await refreshPlaylists();
  }

  List<Track> playlistTracks(Playlist p) => [
        for (final id in p.trackIds)
          if (tracksById[id] != null) tracksById[id]!,
      ];

  Future<void> rescanAndSync() async {
    await api.scan();
    // give the server thread a beat to register the scan
    await Future<void>.delayed(const Duration(milliseconds: 300));
    var s = await api.status();
    var tries = 0;
    while (s["scanning"] == true && tries < 300) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      s = await api.status();
      tries++;
    }
    await syncLibrary();
  }

  void _applyLibrary(Map<String, dynamic> json) {
    albums = ((json["albums"] as List?) ?? [])
        .map((a) => Album.fromJson(a as Map<String, dynamic>))
        .toList();
    tracks = ((json["tracks"] as List?) ?? [])
        .map((t) => Track.fromJson(t as Map<String, dynamic>))
        .toList();

    albumById = {for (final a in albums) a.id: a};
    tracksByAlbum = {};
    for (final t in tracks) {
      tracksByAlbum.putIfAbsent(t.albumId, () => []).add(t);
    }
    tracksByAlbum.forEach((_, list) {
      list.sort((a, b) =>
          (a.trackNo ?? 9999).compareTo(b.trackNo ?? 9999));
    });
    tracksById = {for (final t in tracks) t.id: t};
    artists = _buildArtists();
    allTracks = _sortedAllTracks();
  }

  List<Artist> _buildArtists() {
    final byArtist = <String, List<Album>>{};
    for (final a in albums) {
      byArtist.putIfAbsent(a.artist, () => []).add(a);
    }
    return byArtist.entries.map((e) {
      final list = e.value
        ..sort((a, b) {
          final y = (a.year ?? 9999).compareTo(b.year ?? 9999);
          if (y != 0) return y;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return Artist(name: e.key, albums: list);
    }).toList()
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<Track> _sortedAllTracks() {
    final list = List<Track>.of(tracks)
      ..sort((a, b) {
        final aa = albumOf(a), bb = albumOf(b);
        final an = (aa?.artist ?? a.artist).toLowerCase();
        final bn = (bb?.artist ?? b.artist).toLowerCase();
        if (an != bn) return an.compareTo(bn);
        final y = (aa?.year ?? 9999).compareTo(bb?.year ?? 9999);
        if (y != 0) return y;
        final aln = (aa?.name ?? "").toLowerCase();
        final bln = (bb?.name ?? "").toLowerCase();
        if (aln != bln) return aln.compareTo(bln);
        return (a.trackNo ?? 9999).compareTo(b.trackNo ?? 9999);
      });
    return list;
  }

  Track? trackById(int id) => tracksById[id];

  /// Every track belonging to an artist, in album/track order.
  List<Track> artistTracks(Artist artist) => [
        for (final a in artist.albums) ...(tracksByAlbum[a.id] ?? const []),
      ];

  /// Total seconds of music in the library.
  double get totalSeconds =>
      tracks.fold(0.0, (sum, t) => sum + (t.duration ?? 0));

  /// Total bytes on disk (0 when the server doesn't report sizes).
  int get totalBytes =>
      tracks.fold(0, (sum, t) => sum + t.size);

  Album? albumOf(Track t) => albumById[t.albumId];

  // ------------------------------------------------------------- offline

  DownloadInfo? downloadInfo(int trackId) => _downloads[trackId];

  String? downloadedPath(int trackId) {
    final info = _downloads[trackId];
    if (info == null || info.phase != DownloadPhase.done) return null;
    return info.path;
  }

  Future<void> downloadTrack(Track t) async {
    if (!_store.supportsDownloads) {
      throw UnsupportedError(
          "Offline downloads aren't available on this platform");
    }
    if (_activeDownloads.contains(t.id) ||
        downloadedPath(t.id) != null) {
      return;
    }
    _activeDownloads.add(t.id);
    _downloads[t.id] = DownloadInfo(phase: DownloadPhase.downloading, path: "");
    notifyListeners();

    try {
      final path = await _store.newOfflinePath(t.ext);
      final resp = await api.download(t.id);
      final total = resp.contentLength ?? 0;

      var lastNotify = 0;
      await _store.writeAll(path, resp.stream, onChunk: (received) {
        if (received - lastNotify > 256 * 1024) {
          lastNotify = received;
          _downloads[t.id] = DownloadInfo(
            phase: DownloadPhase.downloading,
            progress: total > 0 ? received / total : 0.0,
            path: path,
          );
          notifyListeners();
        }
      });

      _downloads[t.id] = DownloadInfo(
        phase: DownloadPhase.done,
        progress: 1,
        path: path,
        size: total,
      );
      await _saveDownloads();
      notifyListeners();
    } catch (_) {
      _downloads.remove(t.id);
      notifyListeners();
      rethrow;
    } finally {
      _activeDownloads.remove(t.id);
    }
  }

  Future<void> deleteDownload(Track t) async {
    final info = _downloads[t.id];
    if (info == null) return;
    await _store.deleteFile(info.path);
    _downloads.remove(t.id);
    await _saveDownloads();
    notifyListeners();
  }

  Future<void> _saveDownloads() async {
    final json = <String, dynamic>{};
    _downloads.forEach((id, info) {
      if (info.phase == DownloadPhase.done) {
        json["$id"] = {"path": info.path, "size": info.size};
      }
    });
    await _store.saveDownloads(json);
  }

  /// How many tracks are fully offline.
  int get downloadedCount =>
      _downloads.values.where((d) => d.phase == DownloadPhase.done).length;
}
