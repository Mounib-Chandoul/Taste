import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import 'theme.dart';

Future<void> showAddToPlaylistSheet(BuildContext context, Track track) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _AddToPlaylistSheet(track: track),
  );
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Add to playlist",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(track.title, style: mono(context, size: 12)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add, color: Palette.accent),
              title: const Text("New playlist"),
              onTap: () => _createAndAdd(context, app),
            ),
            const Divider(),
            if (app.playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("No playlists yet. Create one above."),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: app.playlists.length,
                  itemBuilder: (context, i) {
                    final p = app.playlists[i];
                    final has = p.trackIds.contains(track.id);
                    return ListTile(
                      leading: Icon(
                        has ? Icons.check_circle : Icons.queue_music,
                        color: has ? Palette.teal : null,
                      ),
                      title: Text(p.name),
                      subtitle: Text("${p.trackIds.length} songs"),
                      onTap: has
                          ? null
                          : () async {
                              await app.addToPlaylist(p.id, track.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndAdd(BuildContext context, AppState app) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New playlist"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Playlist name"),
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
    if (name == null || name.isEmpty) return;
    await app.createPlaylist(name);
    final created = app.playlists.isNotEmpty ? app.playlists.first : null;
    if (created != null) {
      await app.addToPlaylist(created.id, track.id);
    }
    if (context.mounted) Navigator.pop(context);
  }
}
