import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../search_engine.dart';
import '../player_service.dart';
import 'album_screen.dart';
import 'artist_screen.dart';
import 'auth_cover.dart';
import 'now_playing_screen.dart';
import 'theme.dart';
import 'track_row.dart';

/// Instant, ranked search over the cached library. No spinner: the engine
/// runs locally, so every keystroke re-scores the whole collection.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = "";

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    // tiny debounce so a fast typist doesn't rescore mid-word
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _query = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: mono(context, color: Palette.fg),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = "");
                        },
                      ),
                hintText: "Songs, artists, albums… fuzzy included",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? _IdleState(app: app)
                : _Results(query: _query),
          ),
        ],
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Try things like:",
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final hint in const [
          "\"bohem\" → Bohemian Rhapsody",
          "\"pink flod\" → fuzzy: Pink Floyd",
          "\"1994\" → hmm, years aren't indexed (yet)",
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(hint)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final tracks =
        SearchEngine.searchTracks(query, app.allTracks, albumOf: app.albumOf);
    final albums = SearchEngine.searchAlbums(query, app.albums);
    final artists = SearchEngine.searchArtists(query, app.artists);

    if (tracks.isEmpty && albums.isEmpty && artists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48),
              const SizedBox(height: 12),
              Text("No matches for \"$query\""),
            ],
          ),
        ),
      );
    }

    // The single highest-scoring hit across every document type.
    Hit<dynamic>? top;
    for (final list in [tracks, albums, artists]) {
      if (list.isNotEmpty && (top == null || list.first.score > top.score)) {
        top = list.first;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (top != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text("Top result",
                style: Theme.of(context).textTheme.titleMedium),
          ),
          _TopResult(hit: top),
        ],
        if (artists.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section("Artists", "${artists.length}"),
          for (final hit in artists.take(8))
            ListTile(
              leading: ClipOval(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: hit.item.coverAlbum != null
                      ? AuthCover(albumId: hit.item.coverAlbum!.id)
                      : const Icon(Icons.person),
                ),
              ),
              title: Text(hit.item.name),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => ArtistScreen(artist: hit.item)),
              ),
            ),
        ],
        if (tracks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section("Songs", "${tracks.length}"),
          for (final hit in tracks.take(10))
            TrackRow(
              track: hit.item,
              queue: tracks.map((h) => h.item).toList(),
              index: tracks.indexOf(hit),
            ),
        ],
        if (albums.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section("Albums", "${albums.length}"),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: albums.length,
              itemBuilder: (context, i) => SizedBox(
                width: 150,
                child: _AlbumTile(album: albums[i].item),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.count);
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Text(count, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TopResult extends StatelessWidget {
  const _TopResult({required this.hit});
  final Hit<dynamic> hit;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final player = context.read<PlayerService>();

    final VoidCallback onTap;
    final Widget content;
    if (hit.item is Track) {
      final track = hit.item as Track;
      onTap = () async {
        final queue = app.allTracks;
        final idx = queue.indexWhere((t) => t.id == track.id);
        await player.playQueue(queue, start: idx < 0 ? 0 : idx);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const NowPlayingScreen(),
              fullscreenDialog: true,
            ),
          );
        }
      };
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge),
          Text(
            "${app.albumOf(track)?.artist ?? track.artist} • Song",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    } else if (hit.item is Album) {
      final album = hit.item as Album;
      onTap = () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => AlbumScreen(album: album)),
          );
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(album.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge),
          Text("${album.artist} • Album",
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    } else {
      final artist = hit.item as Artist;
      onTap = () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => ArtistScreen(artist: artist)),
          );
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(artist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge),
          Text("Artist", style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: _coverFor(hit.item, app),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverFor(dynamic item, AppState app) {
    final albumId = switch (item) {
      Track t => t.albumId,
      Album a => a.id,
      Artist a => a.coverAlbum?.id,
      _ => null,
    };
    if (albumId == null) return const Icon(Icons.person);
    return AuthCover(albumId: albumId);
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album});
  final Album album;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AlbumScreen(album: album)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AuthCover(albumId: album.id, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(album.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
