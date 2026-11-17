import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/core.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../domain/audio/audio_player_service.dart';
import '../../providers/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final recentAsync = ref.watch(recentlyPlayedProvider);
    final madeAsync = ref.watch(madeForYouProvider);

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final isWide = w >= 1024;
      final isTablet = w >= 600 && w < 1024;
      final pad = EdgeInsets.fromLTRB(16, 16, 16, w >= 700 ? 8 : 16);

      Widget content;
      if (isWide) {
        content = _WideBento(
          user: userAsync.asData?.value,
          recent: recentAsync.asData?.value ?? const [],
          madeForYou: madeAsync.asData?.value ?? const [],
        );
      } else if (isTablet) {
        content = _TabletBento(
          user: userAsync.asData?.value,
          recent: recentAsync.asData?.value ?? const [],
          madeForYou: madeAsync.asData?.value ?? const [],
        );
      } else {
        content = _PhoneBento(
          user: userAsync.asData?.value,
          recent: recentAsync.asData?.value ?? const [],
          madeForYou: madeAsync.asData?.value ?? const [],
        );
      }

      return SingleChildScrollView(
        padding: pad,
        child: content,
      );
    });
  }
}

class _PhoneBento extends StatelessWidget {
  const _PhoneBento({this.user, required this.recent, required this.madeForYou});
  final UserProfile? user;
  final List<Track> recent;
  final List<Playlist> madeForYou;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _stagger([
        const _TerminalHeader(
          prompt: 'user@aesthetic ~ \$ dashboard',
          subtitle: 'good evening. your grid is humming.',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ProfileCard(user: user)),
            const SizedBox(width: 12),
            const Expanded(child: _ClockCard()),
          ],
        ),
        const SizedBox(height: 12),
        const _NowPlayingCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _DailyMinutesCard(user: user)),
            const SizedBox(width: 12),
            const Expanded(child: _VolumeCard()),
          ],
        ),
        const SizedBox(height: 12),
        const _QuickLinksCard(),
        const SizedBox(height: 12),
        const _QuoteCard(),
        const SizedBox(height: 12),
        _RecentlyPlayedCard(tracks: recent),
        const SizedBox(height: 12),
        _MadeForYouCard(playlists: madeForYou),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _TabletBento extends StatelessWidget {
  const _TabletBento({this.user, required this.recent, required this.madeForYou});
  final UserProfile? user;
  final List<Track> recent;
  final List<Playlist> madeForYou;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _stagger([
        const _TerminalHeader(
          prompt: 'user@aesthetic ~ \$ dashboard',
          subtitle: 'bento grid online. tap a card to dive in.',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _ProfileCard(user: user)),
            const SizedBox(width: 12),
            const Expanded(flex: 2, child: _ClockCard()),
            const SizedBox(width: 12),
            const Expanded(flex: 2, child: _QuickLinksCard()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 3, child: _NowPlayingCard()),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _DailyMinutesCard(user: user),
                  const SizedBox(height: 12),
                  const _VolumeCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _RecentlyPlayedCard(tracks: recent)),
            const SizedBox(width: 12),
            const Expanded(flex: 2, child: _QuoteCard()),
          ],
        ),
        const SizedBox(height: 12),
        _MadeForYouCard(playlists: madeForYou),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _WideBento extends StatelessWidget {
  const _WideBento({this.user, required this.recent, required this.madeForYou});
  final UserProfile? user;
  final List<Track> recent;
  final List<Playlist> madeForYou;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _stagger([
        const _TerminalHeader(
          prompt: 'user@aesthetic ~ \$ dashboard --wide',
          subtitle: 'desktop rice mode. all widgets docked.',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _ProfileCard(user: user)),
                      const SizedBox(width: 12),
                      const Expanded(flex: 2, child: _ClockCard()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _NowPlayingCard(),
                  const SizedBox(height: 12),
                  _RecentlyPlayedCard(tracks: recent),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _DailyMinutesCard(user: user)),
                      const SizedBox(width: 12),
                      const Expanded(child: _VolumeCard()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _QuickLinksCard(),
                  const SizedBox(height: 12),
                  const _QuoteCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MadeForYouCard(playlists: madeForYou),
        const SizedBox(height: 24),
      ]),
    );
  }
}

List<Widget> _stagger(List<Widget> children) {
  return [
    for (var i = 0; i < children.length; i++)
      children[i]
          .animate()
          .fadeIn(delay: (40 * i).ms, duration: 220.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.08,
            end: 0,
            delay: (40 * i).ms,
            duration: 220.ms,
            curve: Curves.easeOutBack,
          ),
  ];
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader({required this.prompt, required this.subtitle});
  final String prompt;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: AppTypography.prompt(color: colors.green)),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTypography.caption()),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({this.user});
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final u = user;
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.accent, width: 3),
              color: colors.cardElevated,
            ),
            clipBehavior: Clip.antiAlias,
            child: u == null
                ? Icon(PhosphorIconsRegular.user, color: colors.textSecondary)
                : CachedNetworkImage(
                    imageUrl: u.avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                        PhosphorIconsRegular.user,
                        color: colors.textSecondary),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u?.username ?? 'listener',
                  style: AppTypography.title(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  u?.handle ?? '@guest',
                  style: AppTypography.caption(),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.cardElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border, width: 2),
                  ),
                  child: Text('ONLINE',
                      style: AppTypography.label(color: colors.green)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockCard extends StatefulWidget {
  const _ClockCard();

  @override
  State<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<_ClockCard> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    final blink = _now.second.isEven ? ':' : ' ';
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final date =
        '${days[_now.weekday - 1]} ${_now.day} ${months[_now.month - 1]}';

    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('user@aesthetic ~ \$ clock',
              style: AppTypography.prompt(color: colors.cyan)),
          const SizedBox(height: 10),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              '$hh$blink$mm',
              style: AppTypography.display(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: 6),
          Text(date, style: AppTypography.caption(color: colors.purple)),
        ],
      ),
    );
  }
}

class _NowPlayingCard extends ConsumerWidget {
  const _NowPlayingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final audio = ref.watch(audioPlayerServiceProvider);
    final snap = ref.watch(audioSnapshotProvider).asData?.value ?? audio.state;
    final track = snap.currentTrack;

    return PixelCard(
      padding: const EdgeInsets.all(14),
      onTap: track == null ? null : () => context.push('/now-playing'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('user@aesthetic ~ \$ now_playing',
              style: AppTypography.prompt(color: colors.green)),
          const SizedBox(height: 12),
          if (track == null)
            Row(
              children: [
                Icon(PhosphorIconsRegular.musicNotesSimple,
                    color: colors.textSecondary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nothing playing. Pick a track to start the vibe.',
                    style: AppTypography.body(color: colors.textSecondary),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'home-art-${track.id}',
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border, width: 3),
                      color: colors.cardElevated,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: track.albumArtUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                          PhosphorIconsRegular.musicNotes,
                          color: colors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title(color: colors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(track.artist, style: AppTypography.caption()),
                      const SizedBox(height: 10),
                      _PixelProgressBar(progress: snap.progress),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          PixelButton.icon(
                            icon: PhosphorIconsBold.shuffle,
                            onTap: () => audio.toggleShuffle(),
                            size: 36,
                            iconSize: 16,
                            selected: snap.shuffle,
                            iconColor: snap.shuffle
                                ? colors.accent
                                : colors.textSecondary,
                            borderColor:
                                snap.shuffle ? colors.accent : colors.border,
                          ),
                          const SizedBox(width: 8),
                          PixelButton.icon(
                            icon: PhosphorIconsBold.skipBack,
                            onTap: () => audio.previous(),
                            size: 36,
                            iconSize: 16,
                          ),
                          const SizedBox(width: 8),
                          PixelButton.icon(
                            icon: snap.playing
                                ? PhosphorIconsFill.pause
                                : PhosphorIconsFill.play,
                            onTap: () => audio.togglePlayPause(),
                            size: 40,
                            iconSize: 18,
                            color: colors.cardElevated,
                            borderColor: colors.accent,
                            iconColor: colors.accent,
                          ),
                          const SizedBox(width: 8),
                          PixelButton.icon(
                            icon: PhosphorIconsBold.skipForward,
                            onTap: () => audio.next(),
                            size: 36,
                            iconSize: 16,
                          ),
                          const SizedBox(width: 8),
                          _RepeatButton(mode: snap.repeatMode, onTap: audio.cycleRepeat),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.mode, required this.onTap});
  final RepeatMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = mode != RepeatMode.off;
    return PixelButton.icon(
      icon: mode == RepeatMode.one
          ? PhosphorIconsBold.repeatOnce
          : PhosphorIconsBold.repeat,
      onTap: onTap,
      size: 36,
      iconSize: 16,
      selected: active,
      iconColor: active ? colors.accent : colors.textSecondary,
      borderColor: active ? colors.accent : colors.border,
    );
  }
}

class _PixelProgressBar extends StatelessWidget {
  const _PixelProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final fill = (w * progress.clamp(0.0, 1.0));
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border, width: 2),
        ),
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.linear,
          width: fill,
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    });
  }
}

class _DailyMinutesCard extends StatelessWidget {
  const _DailyMinutesCard({this.user});
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listened = user?.dailyMinutesListened ?? 0;
    final goal = (user?.dailyMinutesGoal ?? 120).clamp(1, 100000);
    final progress = (listened / goal).clamp(0.0, 1.0);
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text('DAILY MIN', style: AppTypography.label(color: colors.textSecondary)),
          const SizedBox(height: 10),
          RingProgress(
            value: progress,
            size: 92,
            strokeWidth: 10,
            color: colors.green,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$listened', style: AppTypography.title(color: colors.textPrimary)),
                Text('min', style: AppTypography.caption()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('goal $goal', style: AppTypography.caption()),
        ],
      ),
    );
  }
}

class _VolumeCard extends ConsumerWidget {
  const _VolumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final audio = ref.watch(audioPlayerServiceProvider);
    final snap = ref.watch(audioSnapshotProvider).asData?.value ?? audio.state;
    final vol = snap.volume;
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text('VOLUME', style: AppTypography.label(color: colors.textSecondary)),
          const SizedBox(height: 10),
          RingProgress(
            value: vol,
            size: 92,
            strokeWidth: 10,
            color: colors.purple,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsFill.speakerHigh,
                    color: colors.textPrimary, size: 20),
                const SizedBox(height: 2),
                Text('${(vol * 100).round()}%',
                    style: AppTypography.caption(color: colors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => audio.setVolume((vol - 0.1).clamp(0.0, 1.0)),
                child: Icon(PhosphorIconsBold.minus,
                    size: 18, color: colors.textSecondary),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => audio.setVolume((vol + 0.1).clamp(0.0, 1.0)),
                child: Icon(PhosphorIconsBold.plus,
                    size: 18, color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icons = <String, IconData>{
      'github': PhosphorIconsRegular.githubLogo,
      'discord': PhosphorIconsRegular.discordLogo,
      'youtube': PhosphorIconsRegular.youtubeLogo,
      'lastfm': PhosphorIconsRegular.musicNotes,
    };
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK LINKS',
              style: AppTypography.label(color: colors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final link in MockData.quickLinks)
                PixelButton.icon(
                  icon: icons[link.icon] ?? PhosphorIconsRegular.link,
                  tooltip: link.label,
                  size: 44,
                  iconSize: 20,
                  iconColor: colors.accentCycle[link.colorIndex % colors.accentCycle.length],
                  borderColor: colors.accentCycle[link.colorIndex % colors.accentCycle.length]
                      .withValues(alpha: 0.7),
                  onTap: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MOOD / QUOTE',
              style: AppTypography.label(color: colors.textSecondary)),
          const SizedBox(height: 10),
          Text(
            MockData.quoteOfDay,
            style: AppTypography.mono(
              size: 13,
              color: colors.textPrimary,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text('— system.log', style: AppTypography.caption(color: colors.yellow)),
        ],
      ),
    );
  }
}

class _RecentlyPlayedCard extends ConsumerWidget {
  const _RecentlyPlayedCard({required this.tracks});
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final audio = ref.watch(audioPlayerServiceProvider);
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('user@aesthetic ~ \$ recently_played',
              style: AppTypography.prompt(color: colors.blue)),
          const SizedBox(height: 10),
          if (tracks.isEmpty)
            Text('No history yet.', style: AppTypography.caption())
          else
            for (var i = 0; i < tracks.length; i++)
              _TrackRow(
                track: tracks[i],
                onTap: () => audio.playTrack(tracks[i], queue: tracks, index: i),
              ),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: track.albumArtUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: colors.cardElevated),
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
      ),
    );
  }
}

class _MadeForYouCard extends StatelessWidget {
  const _MadeForYouCard({required this.playlists});
  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MADE FOR YOU',
              style: AppTypography.label(color: colors.textSecondary)),
          const SizedBox(height: 10),
          if (playlists.isEmpty)
            Text('Refreshing picks...', style: AppTypography.caption())
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _PlaylistTile(playlist: playlists[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      radius: 12,
      shadowOffset: const Offset(4, 4),
      onTap: () => context.push('/playlist/${playlist.id}'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.border, width: 2),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: playlist.coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: colors.cardElevated),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playlist.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
