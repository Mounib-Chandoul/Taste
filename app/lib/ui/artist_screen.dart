import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../player_service.dart';
import 'album_screen.dart';
import 'auth_cover.dart';
import 'track_row.dart';

/// An artist page: derived entirely on the client from the cached library.
class ArtistScreen extends StatelessWidget {
  const ArtistScreen({super.key, required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final player = context.watch<PlayerService>();
    final tracks = app.artistTracks(artist);
    final playingThis = player.hasTrack &&
        player.current != null &&
        tracks.any((t) => t.id == player.current!.id);

    return Scaffold(
      appBar: AppBar(title: Text(artist.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: artist.coverAlbum != null
                        ? AuthCover(albumId: artist.coverAlbum!.id)
                        : const Icon(Icons.person, size: 44),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artist.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        "${artist.albums.length} albums • "
                        "${tracks.length} songs",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: tracks.isEmpty
                  ? null
                  : () => context.read<PlayerService>().playQueue(
                        tracks,
                        start: 0,
                      ),
              icon: playingThis
                  ? const Icon(Icons.graphic_eq)
                  : const Icon(Icons.play_arrow),
              label: Text(playingThis ? "Playing artist" : "Play artist"),
            ),
          ),
          if (artist.albums.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text("Albums",
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: artist.albums.length,
                itemBuilder: (context, i) {
                  final album = artist.albums[i];
                  return SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AlbumScreen(album: album),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AuthCover(
                                albumId: album.id,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.year != null ? "${album.year}" : "",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text("All songs",
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (var i = 0; i < tracks.length; i++)
            TrackRow(track: tracks[i], queue: tracks, index: i),
        ],
      ),
    );
  }
}
