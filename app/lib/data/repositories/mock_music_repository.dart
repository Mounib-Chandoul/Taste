import '../mock/mock_data.dart';
import '../models/models.dart';
import 'music_repository.dart';

class MockMusicRepository implements MusicRepository {
  const MockMusicRepository();

  @override
  Future<UserProfile> getCurrentUser() async => MockData.user;

  @override
  Future<List<Artist>> getArtists() async => MockData.artists;

  @override
  Future<List<Track>> getTracks() async => MockData.tracks;

  @override
  Future<List<Playlist>> getPlaylists() async => MockData.playlists;

  @override
  Future<List<Track>> getRecentlyPlayed() async => MockData.recentlyPlayed();

  @override
  Future<List<Playlist>> getMadeForYou() async => MockData.madeForYou();

  @override
  Future<List<Track>> searchTracks(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return MockData.tracks;
    return MockData.tracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<LibrarySearchResults> search(String query, {int limit = 30}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return LibrarySearchResults.empty;
    final tracks = (await searchTracks(query)).take(limit).toList();
    final artists = MockData.artists
        .where((a) => a.name.toLowerCase().contains(q))
        .take(limit)
        .toList();
    return LibrarySearchResults(tracks: tracks, artists: artists);
  }

  @override
  Future<List<String>> genres() async => const [
        'synthwave',
        'lofi',
        'chiptune',
        'ambient',
        'jazz',
      ];

  @override
  Future<List<Track>> randomTracks({int limit = 20}) async {
    final tracks = [...MockData.tracks]..shuffle();
    return tracks.take(limit).toList();
  }
}
