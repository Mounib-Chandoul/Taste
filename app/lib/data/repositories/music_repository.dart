import '../models/models.dart';

abstract class MusicRepository {
  Future<UserProfile> getCurrentUser();
  Future<List<Artist>> getArtists();
  Future<List<Track>> getTracks();
  Future<List<Playlist>> getPlaylists();
  Future<List<Track>> getRecentlyPlayed();
  Future<List<Playlist>> getMadeForYou();
  Future<List<Track>> searchTracks(String query);

  /// Ranked search. The backend implementation delegates to `/api/search`;
  /// the mock implementation filters its local catalogue.
  Future<LibrarySearchResults> search(String query, {int limit = 30});

  Future<List<String>> genres();
  Future<List<Track>> randomTracks({int limit = 20});
}
