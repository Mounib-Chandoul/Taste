class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.album,
    required this.albumArtUrl,
    required this.duration,
    this.lyrics = const [],
    this.ext = '',
  });

  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String album;
  final String albumArtUrl;
  final Duration duration;

  /// Timed/line lyrics for the lyrics view; plain lines when timing is absent.
  final List<String> lyrics;

  /// Original file extension (used to pick a sensible offline filename).
  final String ext;
}
