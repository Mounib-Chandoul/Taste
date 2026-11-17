class Album {
  final int id;
  final String name;
  final String artist;
  final int? year;

  Album({required this.id, required this.name, required this.artist, this.year});

  factory Album.fromJson(Map<String, dynamic> j) => Album(
        id: j["id"] as int,
        name: (j["name"] as String?) ?? "Unknown Album",
        artist: (j["artist"] as String?) ?? "Unknown Artist",
        year: j["year"] as int?,
      );
}

/// A grouping derived client-side from the albums list - the server stays
/// schema-simple and the app reshapes its cached copy however it likes.
class Artist {
  final String name;
  final List<Album> albums;

  Artist({required this.name, required this.albums});

  Album? get coverAlbum => albums.isEmpty ? null : albums.first;
}

class Track {
  final int id;
  final String title;
  final String artist;
  final int albumId;
  final int? trackNo;
  final double? duration; // seconds
  final int size; // bytes (0 when the server predates the field)
  final String ext;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumId,
    this.trackNo,
    this.duration,
    this.size = 0,
    required this.ext,
  });

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j["id"] as int,
        title: (j["title"] as String?) ?? "Unknown Title",
        artist: (j["artist"] as String?) ?? "Unknown Artist",
        albumId: (j["album_id"] as num).toInt(),
        trackNo: j["track_no"] as int?,
        duration: (j["duration"] as num?)?.toDouble(),
        size: (j["size"] as num?)?.toInt() ?? 0,
        ext: (j["ext"] as String?) ?? "",
      );

  String durationLabel() {
    final d = duration;
    if (d == null || d <= 0) return "";
    final m = d ~/ 60;
    final s = (d % 60).round().toString().padLeft(2, "0");
    return "$m:$s";
  }
}

class Playlist {
  final int id;
  final String name;
  final List<int> trackIds;

  Playlist({required this.id, required this.name, required this.trackIds});

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j["id"] as int,
        name: (j["name"] as String?) ?? "Playlist",
        trackIds: ((j["track_ids"] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}
