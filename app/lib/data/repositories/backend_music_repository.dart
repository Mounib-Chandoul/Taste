import 'dart:math' as math;

import '../../api.dart';
import '../../domain/audio/playback_source.dart';
import '../../models.dart' as real;
import '../models/models.dart' as pixel;
import 'music_repository.dart';

/// Adapts the Music Lab FastAPI backend to the Pixel UI domain.
///
/// Login/splash build this once from a cached or freshly fetched
/// `/api/library` payload. Search, genres, random mixes and playlist writes go
/// straight to the server; library reads come from the cached snapshot so the
/// UI stays instant and works while the LAN server is briefly unavailable.
class BackendMusicRepository implements MusicRepository {
  BackendMusicRepository({
    required this.api,
    required Map<String, dynamic> library,
    required String username,
    List<Map<String, dynamic>> playlists = const [],
  })  : _username = username,
        _playlistsRaw = playlists {
    _applyLibrary(library);
  }

  final ServerApi api;
  String _username;
  List<Map<String, dynamic>> _playlistsRaw;

  List<real.Album> _albums = const [];
  List<real.Track> _tracks = const [];
  final Map<int, real.Album> _albumById = {};
  final Map<int, int> _albumIdByTrackId = {};
  final Map<String, pixel.Artist> _artistsByName = {};
  List<pixel.Artist> _artists = const [];
  List<pixel.Track> _pixelTracks = const [];
  final Map<int, pixel.Track> _pixelTrackById = {};
  List<pixel.Playlist> _playlists = const [];

  void updateLibrary(Map<String, dynamic> library, {String? username}) {
    if (username != null) _username = username;
    _applyLibrary(library);
  }

  void updatePlaylists(List<Map<String, dynamic>> playlists) {
    _playlistsRaw = playlists;
    _rebuildPlaylists();
  }

  void _applyLibrary(Map<String, dynamic> json) {
    _albums = ((json['albums'] as List?) ?? [])
        .whereType<Map>()
        .map((a) => real.Album.fromJson(Map<String, dynamic>.from(a)))
        .toList();
    _tracks = ((json['tracks'] as List?) ?? [])
        .whereType<Map>()
        .map((t) => real.Track.fromJson(Map<String, dynamic>.from(t)))
        .toList();

    _albumById
      ..clear()
      ..addEntries(_albums.map((a) => MapEntry(a.id, a)));
    _albumIdByTrackId
      ..clear()
      ..addEntries(_tracks.map((t) => MapEntry(t.id, t.albumId)));

    _artistsByName.clear();
    final byArtist = <String, List<real.Album>>{};
    for (final a in _albums) {
      byArtist.putIfAbsent(a.artist, () => []).add(a);
    }

    _artists = byArtist.entries.map((e) {
      final albums = [...e.value]
        ..sort((a, b) {
          final y = (a.year ?? 9999).compareTo(b.year ?? 9999);
          if (y != 0) return y;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      final cover = albums.isNotEmpty
          ? _coverUrl(albums.first.id)
          : _fallbackArt(e.key);
      final artist = pixel.Artist(
        id: _slug(e.key),
        name: e.key,
        imageUrl: cover,
        monthlyListeners:
            12000 + math.Random(e.key.hashCode).nextInt(900000),
        bio: 'Streaming from your Music Lab library.',
        genres: const [],
      );
      _artistsByName[e.key.toLowerCase()] = artist;
      return artist;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _pixelTrackById.clear();
    _pixelTracks = [
      for (final t in _tracks) _toPixelTrack(t),
    ];

    _rebuildPlaylists();
  }

  pixel.Track _toPixelTrack(real.Track t) {
    final album = _albumById[t.albumId];
    final artistName = album?.artist ?? t.artist;
    final artist = _artistsByName[artistName.toLowerCase()];
    final pt = pixel.Track(
      id: t.id.toString(),
      title: t.title,
      artist: artistName,
      artistId: artist?.id ?? _slug(artistName),
      album: album?.name ?? 'Unknown Album',
      albumArtUrl: _coverUrl(t.albumId),
      duration: Duration(
        milliseconds: ((t.duration ?? 0) * 1000).round().clamp(0, 1 << 31),
      ),
      lyrics: const [],
      ext: t.ext,
    );
    _pixelTrackById[t.id] = pt;
    return pt;
  }

  void _rebuildPlaylists() {
    _playlists = _playlistsRaw
        .map(_playlistFromJson)
        .whereType<pixel.Playlist>()
        .toList();
  }

  pixel.Playlist? _playlistFromJson(Map<dynamic, dynamic> j) {
    final map = Map<String, dynamic>.from(j);
    final id = (map['id'] as num?)?.toInt();
    if (id == null) return null;
    final name = (map['name'] as String?) ?? 'Playlist';
    final ids = ((map['track_ids'] as List?) ?? [])
        .map((e) => (e as num).toInt())
        .where(_pixelTrackById.containsKey)
        .map((tid) => tid.toString())
        .toList();
    final cover = ids.isNotEmpty
        ? (_pixelTrackById[int.tryParse(ids.first) ?? -1]?.albumArtUrl ??
            _fallbackArt(name))
        : _fallbackArt(name);
    return pixel.Playlist(
      id: id.toString(),
      title: name,
      description: '${ids.length} tracks • from server',
      coverUrl: cover,
      trackIds: ids,
      owner: _username,
    );
  }

  String _coverUrl(int albumId) => api.coverUriWithToken(albumId).toString();

  static const _avatarSeeds = ['nova', 'aria', 'kai', 'milo', 'luna'];

  String _fallbackArt(String seed) {
    final pick = _avatarSeeds[seed.hashCode.abs() % _avatarSeeds.length];
    return 'https://picsum.photos/seed/$pick-${seed.hashCode.abs()}/400/400';
  }

  String _slug(String s) {
    final slug = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'artist' : slug;
  }

  // ---------------------------------------------------------- lookup helpers

  pixel.Track? pixelTrackForRealId(int id) => _pixelTrackById[id];

  int? realIdForPixelTrack(String id) => int.tryParse(id);

  String streamUrlForPixelTrack(String id) {
    final rid = realIdForPixelTrack(id);
    if (rid == null) return '';
    return api.streamUrlWithToken(rid);
  }

  String coverUrlForPixelTrack(String id) {
    final rid = realIdForPixelTrack(id);
    if (rid == null) return _fallbackArt(id);
    final albumId = _albumIdByTrackId[rid];
    if (albumId == null) return _fallbackArt(id);
    return _coverUrl(albumId);
  }

  /// Resolves a Pixel track into a loadable, correctly tagged audio source.
  PlaybackSource? playbackSourceForPixelTrack(String id) {
    final track = _pixelTrackById[int.tryParse(id) ?? -1];
    if (track == null) return null;
    return PlaybackSource(
      uri: Uri.parse(streamUrlForPixelTrack(id)),
      artUri: Uri.tryParse(coverUrlForPixelTrack(id)),
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      headers: Map<String, String>.from(api.headers),
    );
  }

  // ------------------------------------------------------------ server calls

  Future<void> refreshPlaylistsFromServer() async {
    updatePlaylists(await api.playlists());
  }

  @override
  Future<pixel.UserProfile> getCurrentUser() async {
    final name = _username.isEmpty ? 'listener' : _username;
    return pixel.UserProfile(
      username: name,
      handle: '@$name',
      avatarUrl: 'https://picsum.photos/seed/$name-avatar/200/200',
      dailyMinutesGoal: 120,
      dailyMinutesListened: 0,
    );
  }

  @override
  Future<List<pixel.Artist>> getArtists() async => _artists;

  @override
  Future<List<pixel.Track>> getTracks() async => _pixelTracks;

  @override
  Future<List<pixel.Playlist>> getPlaylists() async {
    try {
      await refreshPlaylistsFromServer();
    } catch (_) {
      // Keep the cached playlists when the server is briefly unreachable.
    }
    return _playlists;
  }

  @override
  Future<List<pixel.Track>> getRecentlyPlayed() async {
    return _pixelTracks.take(math.min(8, _pixelTracks.length)).toList();
  }

  @override
  Future<List<pixel.Playlist>> getMadeForYou() async {
    try {
      await refreshPlaylistsFromServer();
    } catch (_) {}
    return _playlists.take(math.min(4, _playlists.length)).toList();
  }

  @override
  Future<List<pixel.Track>> searchTracks(String query) async {
    return (await search(query)).tracks;
  }

  @override
  Future<pixel.LibrarySearchResults> search(String query, {int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return pixel.LibrarySearchResults.empty;
    final body = await api.search(q, limit: limit);

    final tracks = ((body['tracks'] as List?) ?? [])
        .whereType<Map>()
        .map((t) => real.Track.fromJson(Map<String, dynamic>.from(t)))
        .map(_toPixelTrack)
        .toList();

    final artists = ((body['artists'] as List?) ?? [])
        .whereType<Map>()
        .map((a) => (a['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .map((name) {
          final existing = _artistsByName[name.toLowerCase()];
          if (existing != null) return existing;
          return pixel.Artist(
            id: _slug(name),
            name: name,
            imageUrl: _fallbackArt(name),
            monthlyListeners: 0,
            bio: 'Streaming from your Music Lab library.',
            genres: const [],
          );
        })
        .toList();

    final albums = ((body['albums'] as List?) ?? [])
        .whereType<Map>()
        .map((a) {
          final map = Map<String, dynamic>.from(a);
          final id = (map['id'] as num?)?.toInt() ?? 0;
          final title = (map['name'] as String?) ?? 'Unknown Album';
          final artist = (map['artist'] as String?) ?? 'Unknown Artist';
          return pixel.SearchAlbum(
            title: title,
            artist: artist,
            artUrl: id > 0 ? _coverUrl(id) : _fallbackArt(title),
          );
        })
        .toList();

    return pixel.LibrarySearchResults(
      tracks: tracks,
      artists: artists,
      albums: albums,
    );
  }

  @override
  Future<List<String>> genres() => api.genres();

  @override
  Future<List<pixel.Track>> randomTracks({int limit = 20}) async {
    final rows = await api.randomTracks(limit: limit);
    return rows
        .map((t) => real.Track.fromJson(t))
        .map(_toPixelTrack)
        .toList();
  }

  // --------------------------------------------------------- playlist writes

  Future<void> createPlaylist(String name) async {
    await api.createPlaylist(name);
    await refreshPlaylistsFromServer();
  }

  Future<void> renamePlaylist(int id, String name) async {
    await api.renamePlaylist(id, name);
    await refreshPlaylistsFromServer();
  }

  Future<void> deletePlaylist(int id) async {
    await api.deletePlaylist(id);
    await refreshPlaylistsFromServer();
  }

  Future<void> addToPlaylist(int playlistId, String pixelTrackId) async {
    final rid = realIdForPixelTrack(pixelTrackId);
    if (rid == null) return;
    await api.addToPlaylist(playlistId, rid);
    await refreshPlaylistsFromServer();
  }

  Future<void> removeFromPlaylist(int playlistId, String pixelTrackId) async {
    final rid = realIdForPixelTrack(pixelTrackId);
    if (rid == null) return;
    await api.removeFromPlaylist(playlistId, rid);
    await refreshPlaylistsFromServer();
  }

  Future<void> reorderPlaylist(
    int playlistId,
    List<String> pixelTrackIds,
  ) async {
    final ids = pixelTrackIds
        .map(realIdForPixelTrack)
        .whereType<int>()
        .toList();
    await api.reorderPlaylist(playlistId, ids);
    await refreshPlaylistsFromServer();
  }
}
