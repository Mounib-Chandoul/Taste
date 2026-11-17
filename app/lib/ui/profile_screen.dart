import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'downloads_screen.dart';
import 'theme.dart';

/// Account / profile hub: user, server, library stats, downloads, settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final hours = (app.totalSeconds / 3600).toStringAsFixed(1);
    final initial = (app.username?.isNotEmpty == true)
        ? app.username![0].toUpperCase()
        : "?";

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Palette.surfaceAlt,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Palette.accent,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.username ?? "Guest",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.serverUrl ?? "Not connected",
                      style: mono(context, size: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StatsRow(
            items: [
              _Stat("${app.tracks.length}", "Songs"),
              _Stat("${app.albums.length}", "Albums"),
              _Stat("${app.artists.length}", "Artists"),
              _Stat("$hours h", "Library"),
            ],
          ),
          if (app.playlists.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "${app.playlists.length} playlists",
              textAlign: TextAlign.center,
              style: mono(context, size: 11),
            ),
          ],
          const SizedBox(height: 24),
          Text("Your stuff", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Tile(
            icon: Icons.download_done,
            title: "Downloads",
            subtitle: app.canDownload
                ? "${app.downloadedCount} songs available offline"
                : "Available on the Android app",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
            ),
          ),
          const SizedBox(height: 20),
          Text("Library & server",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Tile(
            icon: Icons.refresh,
            title: "Refresh library",
            subtitle: app.syncing
                ? "Syncing…"
                : (app.serverReachable
                    ? "Sync albums, songs and playlists"
                    : "Server unreachable — showing cached library"),
            onTap: app.syncing ? null : () => _sync(context),
          ),
          _Tile(
            icon: Icons.folder_open,
            title: "Rescan music folder",
            subtitle: "Re-read files from the PC music directory",
            onTap: app.syncing ? null : () => _rescan(context),
          ),
          const SizedBox(height: 20),
          Text("About", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Music Lab",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Self-hosted streaming from your own PC.\n"
                    "Local-first, private, built with Flutter + FastAPI.",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Palette.dim),
                  ),
                  const SizedBox(height: 8),
                  Text("v0.2", style: mono(context, size: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text("Disconnect"),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final app = context.read<AppState>();
    try {
      await app.syncLibrary();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Library refreshed")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync failed: $e")),
        );
      }
    }
  }

  Future<void> _rescan(BuildContext context) async {
    final app = context.read<AppState>();
    try {
      await app.rescanAndSync();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rescan complete")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rescan failed: $e")),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Disconnect?"),
        content: const Text(
          "You can reconnect later. Offline downloads stay on this device.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );
    if (ok == true) await app.logout();
  }
}

class _Stat {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<_Stat> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            for (final s in items)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      s.value,
                      style: mono(
                        context,
                        size: 18,
                        color: Palette.fg,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(s.label,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Palette.dim)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Palette.accent),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
