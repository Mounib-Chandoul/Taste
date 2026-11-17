import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../player_service.dart';
import 'auth_cover.dart';
import 'now_playing_screen.dart';

/// Downloads tab: everything available fully offline.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final downloaded = app.tracks
        .where((t) => app.downloadedPath(t.id) != null)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text("Offline")),
      body: downloaded.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "Nothing downloaded yet.\n\nOpen an album and tap the "
                  "download icon on a song. Downloaded songs play with "
                  "zero connection.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: downloaded.length,
              itemBuilder: (context, i) {
                final t = downloaded[i];
                final info = app.downloadInfo(t.id)!;
                final size = info.size / (1024 * 1024);
                final album = app.albumOf(t);
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: AuthCover(albumId: t.albumId),
                    ),
                  ),
                  title: Text(t.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    "${album?.name ?? ""} • ${size.toStringAsFixed(1)} MB"
                    " • ${t.durationLabel()}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: "Remove from offline",
                    onPressed: () => app.deleteDownload(t),
                  ),
                  onTap: () {
                    context
                        .read<PlayerService>()
                        .playQueue(downloaded, start: i);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NowPlayingScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
