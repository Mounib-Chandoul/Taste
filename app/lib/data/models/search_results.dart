import 'artist.dart';
import 'track.dart';

/// A lightweight album hit from server-side search.
class SearchAlbum {
  const SearchAlbum({
    required this.title,
    required this.artist,
    this.artUrl = '',
  });

  final String title;
  final String artist;
  final String artUrl;
}

/// Ranked results from `/api/search`, already mapped to the Pixel UI models.
class LibrarySearchResults {
  const LibrarySearchResults({
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
  });

  final List<Track> tracks;
  final List<Artist> artists;
  final List<SearchAlbum> albums;

  bool get isEmpty => tracks.isEmpty && artists.isEmpty && albums.isEmpty;

  static const empty = LibrarySearchResults();
}
