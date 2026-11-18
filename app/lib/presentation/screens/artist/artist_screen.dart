import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/core.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/mini_player.dart';

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

String _slug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'artist' : slug;
}

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artistId});
  final String artistId;

  List<_AlbumItem> _albumsFor(List<Track> tracks) {
    final map = <String, _AlbumItem>{};
    for (final t in tracks) {
      final key = t.album;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final audio = ref.watch(audioPlayerServiceProvider);
    final artists =
        ref.watch(artistsProvider).asData?.value ?? const <Artist>[];
    final allTracks =
        ref.watch(tracksProvider).asData?.value ?? const <Track>[];
    final artist = artists.firstWhere(
      (a) => a.id == artistId || _slug(a.name) == artistId,
      orElse: () => Artist(
        id: artistId,
        name: artistId.replaceAll('-', ' '),
        imageUrl: '',
        monthlyListeners: 0,
      ),
    );
    final tracks =
        allTracks.where((t) => t.artistId == artist.id).toList();
    final albums = _albumsFor(tracks);

    return Scaffold(
      backgroundColor: colors.background,
      body: GridBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 340,
              backgroundColor: colors.card,
              foregroundColor: colors.textPrimary,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: PixelButton.icon(
                  icon: PhosphorIconsBold.arrowLeft,
                  onTap: () => context.pop(),
                  size: 36,
                  iconSize: 18,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _ArtistHeader(
                  artist: artist,
                  trackCount: tracks.length,
                  onPlay: tracks.isEmpty
                      ? null
                      : () => audio.playQueue(tracks, startIndex: 0),
                  onShuffle: tracks.isEmpty
                      ? null
                      : () {
                          final shuffled = [...tracks]..shuffle();
                          audio.playQueue(shuffled, startIndex: 0);
                        },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('cat ./artists/${artist.id}.bio',
                        style: AppTypography.prompt(color: colors.cyan)),
                    const SizedBox(height: 8),
                    PixelCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final g in artist.genres)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: colors.cardElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: colors.purple, width: 2),
                                  ),
                                  child: Text(g,
                                      style: AppTypography.label(
                                          color: colors.purple)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(artist.bio, style: AppTypography.body()),
                          const SizedBox(height: 8),
                          Text(
                            '${_fmtListeners(artist.monthlyListeners)} monthly listeners',
                            style: AppTypography.caption(color: colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text('ls ./albums',
                      style: AppTypography.prompt(color: colors.green)),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 188,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: albums.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final a = albums[i];
                      return PixelCard(
                        onTap: () => context.push('/album', extra: {
                          'title': a.title,
                          'artist': a.artist,
                          'artUrl': a.artUrl,
                        }),
                        radius: 12,
                        shadowOffset: const Offset(4, 4),
                        child: SizedBox(
                          width: 132,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(10)),
                                  child: CachedNetworkImage(
                                    imageUrl: a.artUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                        color: colors.cardElevated),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.label(
                                            color: colors.textPrimary)),
                                    Text('${a.tracks.length} tracks',
                                        style: AppTypography.caption()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text('ls ./tracks --popular',
                    style: AppTypography.prompt(color: colors.green)),
              ),
            ),
            if (tracks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('No tracks found.', style: AppTypography.caption()),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final t = tracks[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TrackRow(
                          index: i + 1,
                          track: t,
                          onTap: () =>
                              audio.playTrack(t, queue: tracks, index: i),
                        ),
                      );
                    },
                    childCount: tracks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: MiniPlayer(
          enableHero: false,
          onExpand: () => context.push('/now-playing'),
        ),
      ),
    );
  }

  static String _fmtListeners(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({
    required this.artist,
    required this.trackCount,
    required this.onPlay,
    required this.onShuffle,
  });
  final Artist artist;
  final int trackCount;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: artist.imageUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: colors.cardElevated),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: colors.card.withValues(alpha: 0.55)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.card.withValues(alpha: 0.1),
                colors.background.withValues(alpha: 0.96),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('user@aesthetic ~ \$ open artist/${artist.id}',
                    style: AppTypography.prompt(color: colors.green)),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.purple, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: colors.hardShadow,
                            offset: const Offset(6, 6),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: artist.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: colors.cardElevated),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            artist.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title(color: colors.textPrimary)
                                .copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${artist.genres.join(" · ")} · $trackCount tracks',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              PixelButton.icon(
                                icon: PhosphorIconsFill.play,
                                onTap: onPlay,
                                size: 44,
                                iconSize: 20,
                                color: colors.cardElevated,
                                borderColor: colors.accent,
                                iconColor: colors.accent,
                                tooltip: 'Play',
                              ),
                              const SizedBox(width: 10),
                              PixelButton.icon(
                                icon: PhosphorIconsBold.shuffle,
                                onTap: onShuffle,
                                size: 40,
                                iconSize: 18,
                                tooltip: 'Shuffle',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow(
      {required this.index, required this.track, required this.onTap});
  final int index;
  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: 12,
      shadowOffset: const Offset(3, 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: AppTypography.caption(color: colors.cyan),
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: track.albumArtUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: colors.cardElevated),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(color: colors.textPrimary)),
                Text(track.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption()),
              ],
            ),
          ),
          Text(_fmt(track.duration), style: AppTypography.caption()),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
