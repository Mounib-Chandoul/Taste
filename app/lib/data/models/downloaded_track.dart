/// A track cached on a real filesystem for offline playback.
class DownloadedTrack {
  const DownloadedTrack({
    required this.trackId,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.artUrl,
    required this.duration,
    required this.ext,
    required this.bytes,
    required this.downloadedAt,
  });

  final int trackId;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String artUrl;
  final Duration duration;
  final String ext;
  final int bytes;
  final int downloadedAt;

  Map<String, dynamic> toJson() => {
        'track_id': trackId,
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'art_url': artUrl,
        'duration_ms': duration.inMilliseconds,
        'ext': ext,
        'bytes': bytes,
        'downloaded_at': downloadedAt,
      };

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) =>
      DownloadedTrack(
        trackId: (json['track_id'] as num?)?.toInt() ?? 0,
        path: (json['path'] as String?) ?? '',
        title: (json['title'] as String?) ?? 'Unknown Title',
        artist: (json['artist'] as String?) ?? 'Unknown Artist',
        album: (json['album'] as String?) ?? 'Unknown Album',
        artUrl: (json['art_url'] as String?) ?? '',
        duration: Duration(
          milliseconds: (json['duration_ms'] as num?)?.toInt() ?? 0,
        ),
        ext: (json['ext'] as String?) ?? '.mp3',
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        downloadedAt: (json['downloaded_at'] as num?)?.toInt() ?? 0,
      );
}
