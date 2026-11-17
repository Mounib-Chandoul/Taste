import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/core.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';

class _AlbumItem {
  const _AlbumItem({
    required this.title,
    required this.artist,
    required this.artUrl,
    required this.tracks,
  });
  final String title;
  final String artist;
  final String artUrl;
  final List<Track> tracks;
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<_AlbumItem> _deriveAlbums(List<Track> tracks) {
    final map = <String, _AlbumItem>{};
    for (final t in tracks) {
      final key = '${t.artist}__${t.album}';
      final existing = map[key];
      if (existing == null) {
        map[key] = _AlbumItem(
          title: t.album,
          artist: t.artist,
          artUrl: t.albumArtUrl,
          tracks: [t],
        );
      } else {
        map[key] = _AlbumItem(
          title: existing.title,
          artist: existing.artist,
          artUrl: existing.artUrl,
          tracks: [...existing.tracks, t],
        );
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final playlists =
        ref.watch(playlistsProvider).asData?.value ?? const <Playlist>[];
    final artists =
        ref.watch(artistsProvider).asData?.value ?? const <Artist>[];
    final tracks = ref.watch(tracksProvider).asData?.value ?? const <Track>[];
    final albums = _deriveAlbums(tracks);

    const tabPrompts = [
      'ls ./playlists',
      'ls ./artists',
      'ls ./albums',
      'ls ./downloads',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('user@aesthetic ~ \$ library',
                  style: AppTypography.prompt(color: colors.green)),
              const SizedBox(height: 4),
              Text(tabPrompts[_tabs.index], style: AppTypography.caption()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _TabBar(controller: _tabs)),
                  const SizedBox(width: 8),
                  _ViewToggle(
                    grid: _grid,
                    onChanged: (v) => setState(() => _grid = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PlaylistsTab(playlists: playlists, grid: _grid),
              _ArtistsTab(artists: artists, grid: _grid),
              _AlbumsTab(albums: albums, grid: _grid),
              _DownloadsTab(grid: _grid),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const labels = ['Playlists', 'Artists', 'Albums', 'Downloads'];
    return PixelCard(
      padding: const EdgeInsets.all(4),
      radius: 12,
      shadowOffset: const Offset(3, 3),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.animateTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutBack,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: controller.index == i
                        ? colors.cardElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: controller.index == i
                          ? colors.accent
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      style: AppTypography.label(
                        color: controller.index == i
                            ? colors.accent
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.grid, required this.onChanged});
  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelButton.icon(
          icon: PhosphorIconsBold.squaresFour,
          size: 38,
          iconSize: 18,
          selected: grid,
          iconColor: grid ? context.colors.accent : context.colors.textSecondary,
          borderColor: grid ? context.colors.accent : context.colors.border,
          onTap: () => onChanged(true),
          tooltip: 'Grid',
        ),
        const SizedBox(width: 6),
        PixelButton.icon(
          icon: PhosphorIconsBold.listBullets,
          size: 38,
          iconSize: 18,
          selected: !grid,
          iconColor: !grid ? context.colors.accent : context.colors.textSecondary,
          borderColor: !grid ? context.colors.accent : context.colors.border,
          onTap: () => onChanged(false),
          tooltip: 'List',
        ),
      ],
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab({required this.playlists, required this.grid});
  final List<Playlist> playlists;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    if (grid) {
      return _GridWrap(
        children: [
          for (var i = 0; i < playlists.length; i++)
            _PlaylistGridItem(
              playlist: playlists[i],
              onTap: () => context.push('/playlist/${playlists[i].id}'),
            ).animate().fadeIn(delay: (30 * i).ms, duration: 180.ms).scale(
                begin: const Offset(0.97, 0.97),
                end: const Offset(1, 1),
                delay: (30 * i).ms,
                duration: 200.ms,
                curve: Curves.easeOutBack),
        ],
      );
    }
    return _ListWrap(
      children: [
        for (var i = 0; i < playlists.length; i++)
          _PlaylistListItem(
            playlist: playlists[i],
            onTap: () => context.push('/playlist/${playlists[i].id}'),
          ).animate().fadeIn(delay: (25 * i).ms, duration: 160.ms).slideX(
              begin: 0.03, end: 0, delay: (25 * i).ms, duration: 180.ms),
      ],
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab({required this.artists, required this.grid});
  final List<Artist> artists;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    if (grid) {
      return _GridWrap(
        children: [
          for (var i = 0; i < artists.length; i++)
            _ArtistGridItem(
              artist: artists[i],
              onTap: () => context.push('/artist/${artists[i].id}'),
            ).animate().fadeIn(delay: (30 * i).ms, duration: 180.ms).scale(
                begin: const Offset(0.97, 0.97),
                end: const Offset(1, 1),
                delay: (30 * i).ms,
                duration: 200.ms,
                curve: Curves.easeOutBack),
        ],
      );
    }
    return _ListWrap(
      children: [
        for (var i = 0; i < artists.length; i++)
          _ArtistListItem(
            artist: artists[i],
            onTap: () => context.push('/artist/${artists[i].id}'),
          ).animate().fadeIn(delay: (25 * i).ms, duration: 160.ms).slideX(
              begin: 0.03, end: 0, delay: (25 * i).ms, duration: 180.ms),
      ],
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({required this.albums, required this.grid});
  final List<_AlbumItem> albums;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    void open(_AlbumItem a) => context.push('/album', extra: {
          'title': a.title,
          'artist': a.artist,
          'artUrl': a.artUrl,
        });
    if (grid) {
      return _GridWrap(
        children: [
          for (var i = 0; i < albums.length; i++)
            _AlbumGridItem(
              album: albums[i],
              onTap: () => open(albums[i]),
            ).animate().fadeIn(delay: (30 * i).ms, duration: 180.ms).scale(
                begin: const Offset(0.97, 0.97),
                end: const Offset(1, 1),
                delay: (30 * i).ms,
                duration: 200.ms,
                curve: Curves.easeOutBack),
        ],
      );
    }
    return _ListWrap(
      children: [
        for (var i = 0; i < albums.length; i++)
          _AlbumListItem(
            album: albums[i],
            onTap: () => open(albums[i]),
          ).animate().fadeIn(delay: (25 * i).ms, duration: 160.ms).slideX(
              begin: 0.03, end: 0, delay: (25 * i).ms, duration: 180.ms),
      ],
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab({required this.grid});
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioPlayerServiceProvider);
    final colors = context.colors;
    final downloads =
        ref.watch(downloadsProvider).asData?.value ?? const <DownloadedTrack>[];
    final tracks = downloads
        .map(
          (d) => Track(
            id: d.trackId.toString(),
            title: d.title,
            artist: d.artist,
            artistId: d.artist,
            album: d.album,
            albumArtUrl: d.artUrl,
            duration: d.duration,
            ext: d.ext,
          ),
        )
        .toList();
    if (tracks.isEmpty) {
      return Center(
        child: PixelCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No downloads yet. Tap the download icon on the now-playing screen.',
            style: AppTypography.caption(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(PhosphorIconsFill.downloadSimple, color: colors.green, size: 16),
          const SizedBox(width: 6),
          Text('${tracks.length} tracks available offline',
              style: AppTypography.caption(color: colors.green)),
        ],
      ),
    );
    if (grid) {
      return _GridWrap(
        header: header,
        children: [
          for (var i = 0; i < tracks.length; i++)
            _TrackGridItem(
              track: tracks[i],
              badge: PhosphorIconsFill.checkCircle,
              onTap: () => audio.playTrack(tracks[i], queue: tracks, index: i),
            ).animate().fadeIn(delay: (30 * i).ms, duration: 180.ms),
        ],
      );
    }
    return _ListWrap(
      header: header,
      children: [
        for (var i = 0; i < tracks.length; i++)
          _TrackListItem(
            track: tracks[i],
            trailingIcon: PhosphorIconsFill.checkCircle,
            trailingColor: colors.green,
            onTap: () => audio.playTrack(tracks[i], queue: tracks, index: i),
          ).animate().fadeIn(delay: (25 * i).ms, duration: 160.ms),
      ],
    );
  }
}

class _GridWrap extends StatelessWidget {
  const _GridWrap({required this.children, this.header});
  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cross = c.maxWidth >= 900
          ? 5
          : c.maxWidth >= 600
              ? 4
              : c.maxWidth >= 380
                  ? 3
                  : 2;
      return CustomScrollView(
        slivers: [
          if (header != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(child: header),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildListDelegate(children),
            ),
          ),
        ],
      );
    });
  }
}

class _ListWrap extends StatelessWidget {
  const _ListWrap({required this.children, this.header});
  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (header != null) header!,
        ...children,
      ],
    );
  }
}

// --- Grid items ---

class _PlaylistGridItem extends StatelessWidget {
  const _PlaylistGridItem({required this.playlist, required this.onTap});
  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      onTap: onTap,
      radius: 12,
      shadowOffset: const Offset(4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Art(imageUrl: playlist.coverUrl, radiusTop: 10),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text('${playlist.trackIds.length} tracks',
                    style: AppTypography.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistGridItem extends StatelessWidget {
  const _ArtistGridItem({required this.artist, required this.onTap});
  final Artist artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      onTap: onTap,
      radius: 12,
      shadowOffset: const Offset(4, 4),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.purple, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: artist.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: colors.cardElevated),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.label(color: colors.textPrimary)),
          Text('Artist', style: AppTypography.caption()),
        ],
      ),
    );
  }
}

class _AlbumGridItem extends StatelessWidget {
  const _AlbumGridItem({required this.album, required this.onTap});
  final _AlbumItem album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      onTap: onTap,
      radius: 12,
      shadowOffset: const Offset(4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Art(imageUrl: album.artUrl, radiusTop: 10)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(color: colors.textPrimary)),
                Text(album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackGridItem extends StatelessWidget {
  const _TrackGridItem({required this.track, required this.onTap, this.badge});
  final Track track;
  final VoidCallback onTap;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      onTap: onTap,
      radius: 12,
      shadowOffset: const Offset(4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Art(imageUrl: track.albumArtUrl, radiusTop: 10),
                if (badge != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Icon(badge, size: 18, color: colors.green),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(color: colors.textPrimary)),
                Text(track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- List items ---

class _PlaylistListItem extends StatelessWidget {
  const _PlaylistListItem({required this.playlist, required this.onTap});
  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        onTap: onTap,
        radius: 12,
        shadowOffset: const Offset(4, 4),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _Thumb(imageUrl: playlist.coverUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: colors.textPrimary)),
                  Text('${playlist.trackIds.length} tracks · ${playlist.owner}',
                      style: AppTypography.caption()),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.playlist, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ArtistListItem extends StatelessWidget {
  const _ArtistListItem({required this.artist, required this.onTap});
  final Artist artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        onTap: onTap,
        radius: 12,
        shadowOffset: const Offset(4, 4),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.purple, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: artist.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: colors.cardElevated),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: colors.textPrimary)),
                  Text('Artist · ${artist.genres.join(", ")}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumListItem extends StatelessWidget {
  const _AlbumListItem({required this.album, required this.onTap});
  final _AlbumItem album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        onTap: onTap,
        radius: 12,
        shadowOffset: const Offset(4, 4),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _Thumb(imageUrl: album.artUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: colors.textPrimary)),
                  Text('${album.artist} · ${album.tracks.length} tracks',
                      style: AppTypography.caption()),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.vinylRecord,
                color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TrackListItem extends StatelessWidget {
  const _TrackListItem({
    required this.track,
    required this.onTap,
    this.trailingIcon,
    this.trailingColor,
  });
  final Track track;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        onTap: onTap,
        radius: 12,
        shadowOffset: const Offset(4, 4),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _Thumb(imageUrl: track.albumArtUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(color: colors.textPrimary)),
                  Text(track.artist, style: AppTypography.caption()),
                ],
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: trailingColor ?? colors.textSecondary, size: 18)
            else
              Text(_fmt(track.duration), style: AppTypography.caption()),
          ],
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.imageUrl, this.radiusTop = 0});
  final String imageUrl;
  final double radiusTop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radiusTop)),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: colors.cardElevated),
        errorWidget: (_, __, ___) => Container(
          color: colors.cardElevated,
          alignment: Alignment.center,
          child: Icon(PhosphorIconsRegular.musicNotes,
              color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(color: colors.cardElevated),
      ),
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
