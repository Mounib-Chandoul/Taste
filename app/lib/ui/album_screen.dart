import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../player_service.dart';
import 'auth_cover.dart';
import 'track_row.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key, required this.album});
  final Album album;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final player = context.watch<PlayerService>();
    final tracks = app.tracksByAlbum[album.id] ?? const <Track>[];
    final playingThis = player.hasTrack &&
        player.current != null &&
        player.current!.albumId == album.id;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            collapsedHeight: 64,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AuthCover(albumId: album.id, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black38, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    "${album.artist}"
                    "${album.year != null ? " • ${album.year}" : ""}"
                    " • ${tracks.length} songs",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: tracks.isEmpty
                        ? null
                        : () => context
                            .read<PlayerService>()
                            .playQueue(tracks, start: 0),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(playingThis ? "Playing album" : "Play album"),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) => TrackRow(
              track: tracks[i],
              queue: tracks,
              index: i,
              showAlbumArtist: false,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
