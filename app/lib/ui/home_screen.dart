import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../player_service.dart';
import 'album_card.dart';
import 'theme.dart';
import 'track_row.dart';

/// Spotify-style landing page: greeting, quick stats, a "shuffle
/// everything" launcher, a pick of albums and a preview of all songs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Deterministic per-open seed: "Jump back in" is random but stable while
  // you look at the screen, so items don't jump around on rebuilds.
  late final int _seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final picks = app.albums.toList()..shuffle(Random(_seed));

    final hour = DateTime.now().hour;
    final greeting = hour < 5
        ? "Night owl mode"
        : hour < 12
            ? "Good morning"
            : hour < 18
                ? "Good afternoon"
                : "Good evening";

    final hours = (app.totalSeconds / 3600).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: Theme.of(context).textTheme.titleMedium),
            Text(
              "${app.albums.length} albums · ${app.tracks.length} songs · $hours h",
              style: mono(context, size: 11),
            ),
          ],
        ),
      ),
      body: app.albums.isEmpty
          ? const _EmptyLibrary()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: FilledButton.icon(
                    onPressed: () => _shuffleAll(context, app),
                    icon: const Icon(Icons.shuffle),
                    label: const Text("Shuffle everything"),
                  ),
                ),
                if (picks.isNotEmpty) ...[
                  _SectionHeader(
                    title: "Jump back in",
                    trailing: TextButton(
                      onPressed: () => _goToLibrary(context),
                      child: const Text("See all"),
                    ),
                  ),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: picks.length.clamp(0, 8),
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => SizedBox(
                        width: 150,
                        child: AlbumCard(album: picks[i]),
                      ),
                    ),
                  ),
                ],
                if (app.allTracks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: "All songs",
                    trailing: TextButton(
                      onPressed: () => _goToLibrary(context),
                      child: const Text("See all"),
                    ),
                  ),
                  for (var i = 0; i < min(6, app.allTracks.length); i++)
                    TrackRow(
                      track: app.allTracks[i],
                      queue: app.allTracks,
                      index: i,
                    ),
                ],
              ],
            ),
    );
  }

  void _shuffleAll(BuildContext context, AppState app) {
    final queue = app.allTracks.toList()..shuffle();
    context.read<PlayerService>().playQueue(queue, start: 0);
  }

  void _goToLibrary(BuildContext context) {
    // The shell owns tab selection; popping to the root list is enough here.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          "No albums yet.\n\nMake sure MUSIC_DIR in the server .env points at "
          "your music folder, then tap refresh.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
