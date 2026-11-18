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

enum CollectionKind { playlist, album }

class CollectionDetailArgs {
  const CollectionDetailArgs.playlist(this.playlist)
      : albumTitle = null,
        albumArtist = null,
        albumArtUrl = null,
        kind = CollectionKind.playlist;

  const CollectionDetailArgs.album({
    required String title,
    required String artist,
    required String artUrl,
  })  : playlist = null,
        albumTitle = title,
        albumArtist = artist,
        albumArtUrl = artUrl,
        kind = CollectionKind.album;

  final CollectionKind kind;
  final Playlist? playlist;
  final String? albumTitle;
  final String? albumArtist;
  final String? albumArtUrl;
}

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.args});
  final CollectionDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final audio = ref.watch(audioPlayerServiceProvider);
    final allTracks = ref.watch(tracksProvider).asData?.value ?? const <Track>[];

    late final String title;
    late final String subtitle;
    late final String artUrl;
    late final List<Track> tracks;
    late final String prompt;

    if (args.kind == CollectionKind.playlist) {
      final p = args.playlist!;
      title = p.title;
      subtitle = '${p.owner} · ${p.trackIds.length} tracks';
      artUrl = p.coverUrl;
      final byId = {for (final t in allTracks) t.id: t};
      tracks = [for (final id in p.trackIds) if (byId[id] != null) byId[id]!];
      prompt = 'cat ./playlists/${p.id}.m3u';
    } else {
      title = args.albumTitle!;
      subtitle = '${args.albumArtist} · album';
      artUrl = args.albumArtUrl!;
      tracks = allTracks
          .where((t) => t.album == title && t.artist == args.albumArtist)
          .toList();
      prompt = 'cat ./albums/${_slug(title)}';
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: GridBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 320,
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
                background: _HeaderBackground(
                  artUrl: artUrl,
                  title: title,
                  subtitle: subtitle,
                  prompt: prompt,
                  tracks: tracks,
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
            if (tracks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('No tracks found.', style: AppTypography.caption()),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final t = tracks[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TrackRow(
                          index: i + 1,
                          track: t,
                          onTap: () => audio.playTrack(t, queue: tracks, index: i),
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

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({
    required this.artUrl,
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.tracks,
    required this.onPlay,
    required this.onShuffle,
  });
  final String artUrl;
  final String title;
  final String subtitle;
  final String prompt;
  final List<Track> tracks;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: artUrl,
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
                colors.card.withValues(alpha: 0.15),
                colors.background.withValues(alpha: 0.95),
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
                Text(prompt, style: AppTypography.prompt(color: colors.green)),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border, width: 3),
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
                        imageUrl: artUrl,
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
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title(color: colors.textPrimary)
                                .copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(subtitle, style: AppTypography.caption()),
                          const SizedBox(height: 4),
                          Text('${tracks.length} songs',
                              style: AppTypography.caption(color: colors.cyan)),
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
  const _TrackRow({required this.index, required this.track, required this.onTap});
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
                Text(track.artist,
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
