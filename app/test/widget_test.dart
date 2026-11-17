import 'package:flutter_test/flutter_test.dart';
import 'package:musiclab/models.dart';

void main() {
  test("Track parses server JSON", () {
    final t = Track.fromJson(const {
      "id": 7,
      "title": "Song A",
      "artist": "Some Artist",
      "album_id": 3,
      "track_no": 2,
      "duration": 214.5,
      "ext": ".flac",
      "stream": "/api/stream/7",
      "download": "/api/download/7",
    });
    expect(t.id, 7);
    expect(t.title, "Song A");
    expect(t.albumId, 3);
    expect(t.durationLabel(), "3:35");
  });

  test("Track falls back to defaults on missing fields", () {
    final t = Track.fromJson(const {
      "id": 1,
      "album_id": 1,
    });
    expect(t.title, "Unknown Title");
    expect(t.artist, "Unknown Artist");
    expect(t.durationLabel(), "");
  });

  test("Album parses server JSON", () {
    final a = Album.fromJson(const {
      "id": 5,
      "name": "An Album",
      "artist": "An Artist",
      "year": 2020,
      "cover": "/api/cover/5",
    });
    expect(a.name, "An Album");
    expect(a.year, 2020);
  });
}
