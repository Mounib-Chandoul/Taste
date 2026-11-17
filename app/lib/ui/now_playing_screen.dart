import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../player_service.dart';
import 'add_to_playlist_sheet.dart';
import 'auth_cover.dart';
import 'equalizer_sheet.dart';
import 'home_shell.dart';
import 'theme.dart';

void _openEqualizer(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider<PlayerService>.value(
      value: context.read<PlayerService>(),
      child: const EqualizerSheet(),
    ),
  );
}

/// Full "Now Playing" page. Responsive: side-by-side on wide screens.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final track = player.current;

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text("Now Playing"),
      ),
      body: track == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;

                final coverWidget = Padding(
                  padding: const EdgeInsets.all(24),
                  child: AuthCover(
                    albumId: track.albumId,
                    fit: BoxFit.contain,
                  ),
                );

                final controls = _Controls(track: track);

                if (wide) {
                  return Row(
                    children: [
                      Expanded(child: coverWidget),
                      SizedBox(width: 380, child: controls),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      AspectRatio(aspectRatio: 1, child: coverWidget),
                      controls,
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final player = context.watch<PlayerService>();
    final raw = player.player;
    final album = app.albumOf(track);

    final total = raw.duration ??
        (track.duration != null && track.duration! > 0
            ? Duration(milliseconds: (track.duration! * 1000).round())
            : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            track.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            "${album?.artist ?? track.artist}"
            "${album != null ? " • ${album.name}" : ""}",
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          StreamBuilder<Duration>(
            stream: raw.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final maxMs = total?.inMilliseconds ?? 0;
              return Column(
                children: [
                  Slider(
                    value: maxMs > 0
                        ? pos.inMilliseconds.clamp(0, maxMs).toDouble()
                        : 0,
                    max: maxMs.toDouble(),
                    onChanged: maxMs > 0
                        ? (v) => raw.seek(Duration(milliseconds: v.round()))
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(pos), style: mono(context, size: 11)),
                      Text(_fmt(total ?? Duration.zero),
                          style: mono(context, size: 11)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: "Shuffle",
                icon: const Icon(Icons.shuffle),
                color: player.shuffleEnabled
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: player.toggleShuffle,
              ),
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.skip_previous),
                onPressed: player.previous,
              ),
              const SizedBox(width: 8),
              const PlayPauseButton(),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.skip_next),
                onPressed: player.next,
              ),
              IconButton(
                tooltip: "Repeat",
                icon: Icon(
                  player.repeatMode == LoopMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                ),
                color: player.repeatMode != LoopMode.off
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: player.cycleRepeat,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: "Add to playlist",
                icon: const Icon(Icons.playlist_add),
                onPressed: () => showAddToPlaylistSheet(context, track),
              ),
              if (PlayerService.hasEqualizer)
                IconButton(
                  tooltip: "Equalizer",
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openEqualizer(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const _DownloadRow(),
        ],
      ),
    );
  }
}

class _DownloadRow extends StatefulWidget {
  const _DownloadRow();

  @override
  State<_DownloadRow> createState() => _DownloadRowState();
}

class _DownloadRowState extends State<_DownloadRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final player = context.watch<PlayerService>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    if (!app.canDownload) return const SizedBox.shrink();

    final info = app.downloadInfo(track.id);

    if (info?.phase == DownloadPhase.done) {
      return Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _confirmRemove(context, app, track),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_done, size: 18),
                SizedBox(width: 6),
                Text("Available offline (tap to remove)"),
              ],
            ),
          ),
        ),
      );
    }

    if (info?.phase == DownloadPhase.downloading) {
      final p = (info!.progress * 100).clamp(0, 100).toStringAsFixed(0);
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text("Downloading… $p%"),
          ],
        ),
      );
    }

    return Center(
      child: FilledButton.tonalIcon(
        onPressed: _busy ? null : () => _download(context, app, track),
        icon: const Icon(Icons.download, size: 18),
        label: const Text("Download for offline"),
      ),
    );
  }

  Future<void> _download(BuildContext context, AppState app, Track track) async {
    setState(() => _busy = true);
    try {
      await app.downloadTrack(track);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AppState app,
    Track track,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove offline copy?"),
        content: const Text("You can download it again while connected."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Remove")),
        ],
      ),
    );
    if (ok == true) await app.deleteDownload(track);
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return "$m:${s.toString().padLeft(2, "0")}";
}
