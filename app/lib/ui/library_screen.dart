import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'album_card.dart';
import 'artist_screen.dart';
import 'auth_cover.dart';
import 'playlist_detail_screen.dart';
import 'theme.dart';
import 'track_row.dart';

/// "Your Library": playlists, albums, artists and all songs.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text("Your Library"),
              if (app.syncing) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: "Playlists"),
              Tab(text: "Albums"),
              Tab(text: "Artists"),
              Tab(text: "Songs"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlaylistsTab(),
            _AlbumsTab(),
            _ArtistsTab(),
            _SongsTab(),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add),
          label: const Text("Create playlist"),
        ),
        const SizedBox(height: 12),
        if (app.playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                const Icon(Icons.queue_music, size: 56, color: Palette.dim),
                const SizedBox(height: 12),
                const Text("No playlists yet"),
                const SizedBox(height: 4),
                Text(
                  "Create one and add your favorite songs.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Palette.dim),
                ),
              ],
            ),
          )
        else
          ...app.playlists.map((p) {
            final tracks = app.playlistTracks(p);
            final coverId = tracks.isNotEmpty ? tracks.first.albumId : null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: coverId != null
                        ? AuthCover(albumId: coverId)
                        : Container(
                            color: Palette.surfaceAlt,
                            child: const Icon(Icons.queue_music,
                                color: Palette.accent),
                          ),
                  ),
                ),
                title: Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("${tracks.length} songs",
                    style: mono(context, size: 11)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailScreen(playlistId: p.id),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New playlist"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Playlist name",
            hintText: "My mix",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<AppState>().createPlaylist(name);
    }
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final albums = app.albums.toList()
      ..sort((a, b) {
        final an = a.artist.toLowerCase(), bn = b.artist.toLowerCase();
        if (an == bn) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return an.compareTo(bn);
      });

    if (app.albums.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "No albums yet.\n\nConnect to your server and make sure its music "
            "folder is set, then refresh from Profile.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) => AlbumCard(album: albums[i]),
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.artists.isEmpty) {
      return const Center(child: Text("No artists yet."));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: app.artists.length,
      itemBuilder: (context, i) {
        final artist = app.artists[i];
        final songCount = app.artistTracks(artist).length;
        return ListTile(
          leading: ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: artist.coverAlbum != null
                  ? AuthCover(albumId: artist.coverAlbum!.id)
                  : Container(
                      color: Palette.surfaceAlt,
                      child: const Icon(Icons.person),
                    ),
            ),
          ),
          title: Text(artist.name),
          subtitle: Text("$songCount songs"),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => ArtistScreen(artist: artist)),
          ),
        );
      },
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.allTracks.isEmpty) {
      return const Center(child: Text("No songs yet."));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: app.allTracks.length,
      itemBuilder: (context, i) => TrackRow(
        track: app.allTracks[i],
        queue: app.allTracks,
        index: i,
      ),
    );
  }
}
