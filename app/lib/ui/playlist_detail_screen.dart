import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../player_service.dart';
import 'auth_cover.dart';
import 'theme.dart';
import 'track_row.dart';

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final int playlistId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final playlist = app.playlists.cast<Playlist?>().firstWhere(
          (p) => p!.id == playlistId,
          orElse: () => null,
        );

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Playlist not found")),
      );
    }

    final tracks = app.playlistTracks(playlist);
    final coverId = tracks.isNotEmpty ? tracks.first.albumId : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: "Rename",
                onPressed: () => _rename(context, playlist),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: "Delete",
                onPressed: () => _delete(context, playlist),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(playlist.name, maxLines: 1),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverId != null)
                    AuthCover(albumId: coverId, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Palette.surfaceAlt, Palette.ink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.queue_music,
                          size: 72, color: Palette.accent),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${tracks.length} songs",
                    style: mono(context, size: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: tracks.isEmpty
                        ? null
                        : () => context
                            .read<PlayerService>()
                            .playQueue(tracks, start: 0),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Play"),
                  ),
                ],
              ),
            ),
          ),
          if (tracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    "This playlist is empty.\n\nOpen any song's menu and tap "
                    "\"Add to playlist\".",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: tracks.length,
              itemBuilder: (context, i) => TrackRow(
                track: tracks[i],
                queue: tracks,
                index: i,
                playlistId: playlist.id,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, Playlist p) async {
    final ctrl = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename playlist"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<AppState>().renamePlaylist(p.id, name);
    }
  }

  Future<void> _delete(BuildContext context, Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete playlist?"),
        content: Text("Delete \"${p.name}\"? This can't be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deletePlaylist(p.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
