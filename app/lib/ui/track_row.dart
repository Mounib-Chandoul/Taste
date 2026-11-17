import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../player_service.dart';
import 'add_to_playlist_sheet.dart';
import 'auth_cover.dart';
import 'now_playing_screen.dart';
import 'theme.dart';

/// One song row: art, title, artist/duration, download state and options.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.queue,
    required this.index,
    this.showAlbumArtist = true,
    this.playlistId,
  });

  final Track track;
  final List<Track> queue;
  final int index;
  final bool showAlbumArtist;
  /// When shown inside a playlist, enables "Remove from this playlist".
  final int? playlistId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final player = context.watch<PlayerService>();
    final isCurrent = player.current?.id == track.id;
    final info = app.downloadInfo(track.id);

    final titleStyle = TextStyle(
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
      color: isCurrent ? Palette.teal : null,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AuthCover(albumId: track.albumId),
              if (isCurrent && player.playing)
                Container(
                  color: Colors.black45,
                  alignment: Alignment.center,
                  child: const Icon(Icons.graphic_eq, size: 18, color: Palette.teal),
                ),
            ],
          ),
        ),
      ),
      title: Text(track.title,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
      subtitle: showAlbumArtist
          ? Text(
              "${app.albumOf(track)?.artist ?? track.artist} · ${track.durationLabel()}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              track.durationLabel(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DownloadButton(track: track, info: info),
          _MoreButton(track: track, playlistId: playlistId),
        ],
      ),
      onTap: () {
        context.read<PlayerService>().playQueue(queue, start: index);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NowPlayingScreen(),
            fullscreenDialog: true,
          ),
        );
      },
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.track, this.playlistId});
  final Track track;
  final int? playlistId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert, size: 20),
      onPressed: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text("Add to playlist"),
                  onTap: () => Navigator.pop(ctx, "add"),
                ),
                if (playlistId != null)
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline),
                    title: const Text("Remove from this playlist"),
                    onTap: () => Navigator.pop(ctx, "remove"),
                  ),
              ],
            ),
          ),
        );
        if (!context.mounted || action == null) return;
        final app = context.read<AppState>();
        if (action == "add") {
          await showAddToPlaylistSheet(context, track);
        } else if (action == "remove" && playlistId != null) {
          await app.removeFromPlaylist(playlistId!, track.id);
        }
      },
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.track, required this.info});
  final Track track;
  final DownloadInfo? info;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.canDownload) return const SizedBox.shrink();
    if (info?.phase == DownloadPhase.done) {
      return const Icon(Icons.download_done, size: 22);
    }
    if (info?.phase == DownloadPhase.downloading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return IconButton(
      icon: const Icon(Icons.download, size: 22),
      tooltip: "Download for offline",
      onPressed: () async {
        try {
          await context.read<AppState>().downloadTrack(track);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Download failed: $e")),
            );
          }
        }
      },
    );
  }
}
