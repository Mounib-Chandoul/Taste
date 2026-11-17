/// Everything the real player needs to load one track.
///
/// A finished offline download sets [filePath]; otherwise [uri] points at the
/// authenticated stream endpoint. [artUri] is embedded in the Android media
/// notification as `MediaItem.artworkUri`.
class PlaybackSource {
  const PlaybackSource({
    required this.uri,
    this.filePath,
    this.artUri,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.duration,
    this.headers = const <String, String>{},
  });

  final Uri uri;
  final String? filePath;
  final Uri? artUri;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;

  /// Sent by just_audio on stream requests. The URL also carries ?token= so
  /// the same source works with older servers and with browser media elements
  /// that cannot set headers.
  final Map<String, String> headers;
}
