import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../player_service.dart';
import 'auth_cover.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'theme.dart';

/// Responsive shell: bottom navigation on phones, navigation rail on
/// tablets/desktop-wide windows. Mini player sits above the nav in both.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.home_outlined, Icons.home, "Home"),
    (Icons.search, Icons.search, "Search"),
    (Icons.library_music_outlined, Icons.library_music, "Library"),
    (Icons.person_outline, Icons.person, "Profile"),
  ];

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        final body = wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.$1),
                          selectedIcon: Icon(d.$2),
                          label: Text(d.$3),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _screens[_index]),
                ],
              )
            : _screens[_index];

        final bottom = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.hasTrack)
              MiniPlayerBar(
                onOpen: () => _openNowPlaying(context),
              ),
            if (!wide)
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: d.$3,
                    ),
                ],
              ),
          ],
        );

        return Scaffold(
          body: body,
          bottomNavigationBar: bottom,
        );
      },
    );
  }
}

void _openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const NowPlayingScreen(),
      fullscreenDialog: true,
    ),
  );
}

/// Compact bar with the current track, above the navigation.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final app = context.watch<AppState>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    final album = app.albumOf(track);

    return Material(
      color: Palette.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MiniProgressHairline(),
          InkWell(
            onTap: onOpen,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: AuthCover(albumId: track.albumId),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            album?.artist ?? track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (player.playing)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: PlayingBars(size: 16),
                      ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: player.previous,
                    ),
                    const PlayPauseButton(size: 44),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: player.next,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2px teal progress line hugging the top of the mini player.
class _MiniProgressHairline extends StatelessWidget {
  const _MiniProgressHairline();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    return StreamBuilder<Duration>(
      stream: player.player.positionStream,
      builder: (context, snap) {
        final totalMs = player.player.duration?.inMilliseconds ?? 0;
        final posMs = (snap.data ?? Duration.zero).inMilliseconds;
        return LinearProgressIndicator(
          value: totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          color: Palette.teal,
          stopIndicatorColor: Palette.teal,
        );
      },
    );
  }
}

/// The classic 3-bar "now playing" animation. Sine-driven with per-bar
/// phase offsets so the bars pulse in a wave, not in lockstep.
class PlayingBars extends StatefulWidget {
  const PlayingBars({super.key, this.size = 16, this.color});
  final double size;
  final Color? color;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Palette.teal;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * pi;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 3; i++)
                FractionallySizedBox(
                  heightFactor:
                      0.3 + 0.7 * (0.5 + 0.5 * sin(t + i * 1.05)),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: widget.size / 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    return SizedBox(
      width: size,
      height: size,
      child: IconButton.filled(
        padding: EdgeInsets.zero,
        iconSize: size * 0.55,
        icon: player.playing
            ? const Icon(Icons.pause)
            : const Icon(Icons.play_arrow),
        onPressed: player.toggle,
      ),
    );
  }
}
