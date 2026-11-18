import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/core.dart';
import '../providers/app_providers.dart';
import 'equalizer_bars.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({
    super.key,
    required this.onExpand,
    this.enableHero = true,
  });

  /// Called when the user taps or swipes up to open full Now Playing.
  final VoidCallback onExpand;

  /// Set false when another MiniPlayer is already mounted in the same
  /// Navigator subtree (e.g. an artist profile pushed over the app shell).
  final bool enableHero;

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  double _dragOffset = 0;

  void _handleDragUpdate(DragUpdateDetails d) {
    setState(() {
      // Only allow upward drag (negative dy) with resistance.
      _dragOffset = (_dragOffset + d.delta.dy).clamp(-72.0, 0.0);
    });
  }

  void _handleDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    final shouldExpand = _dragOffset < -28 || velocity < -250;
    setState(() => _dragOffset = 0);
    if (shouldExpand) {
      HapticFeedback.selectionClick();
      widget.onExpand();
    }
  }

  void _handleDragCancel() {
    if (_dragOffset != 0) setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final snapAsync = ref.watch(audioSnapshotProvider);
    final audio = ref.watch(audioPlayerServiceProvider);
    final snap = snapAsync.asData?.value ?? audio.state;
    final track = snap.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final colors = context.colors;
    final lift = (-_dragOffset / 72).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _dragOffset, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: PixelCard(
          radius: 14,
          borderWidth: 2.5,
          shadowOffset: Offset(4, 4 + (lift * 4)),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          color: colors.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onExpand();
                },
                onVerticalDragUpdate: _handleDragUpdate,
                onVerticalDragEnd: _handleDragEnd,
                onVerticalDragCancel: _handleDragCancel,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Drag handle
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 36 + (lift * 10),
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                          colors.border, colors.accent, lift * 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    HeroMode(
                      enabled: widget.enableHero,
                      child: Hero(
                        tag: 'now-playing-art-${track.id}',
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border, width: 2),
                            color: colors.cardElevated,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: track.albumArtUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: colors.cardElevated),
                            errorWidget: (_, __, ___) => Icon(
                              PhosphorIconsRegular.musicNotes,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label(color: colors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    EqualizerBars(
                      active: snap.playing,
                      width: 22,
                      height: 16,
                      barCount: 4,
                    ),
                    const SizedBox(width: 6),
                    _MiniIconButton(
                      icon: snap.playing
                          ? PhosphorIconsFill.pause
                          : PhosphorIconsFill.play,
                      accent: true,
                      onTap: () => audio.togglePlayPause(),
                    ),
                    const SizedBox(width: 4),
                    _MiniIconButton(
                      icon: PhosphorIconsBold.skipForward,
                      onTap: () => audio.next(),
                    ),
                  ],
                ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Scrubbable pixel-style progress bar.
              LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                double progressFor(double dx) {
                  if (w <= 0) return 0;
                  return (dx / w).clamp(0.0, 1.0);
                }

                void seekTo(double dx) {
                  final dur = snap.duration;
                  if (dur.inMilliseconds <= 0) return;
                  final p = progressFor(dx);
                  audio.seek(
                    Duration(milliseconds: (dur.inMilliseconds * p).round()),
                  );
                }

                final fill = (w * snap.progress.clamp(0.0, 1.0)).clamp(0.0, w);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    HapticFeedback.selectionClick();
                    seekTo(d.localPosition.dx);
                  },
                  onHorizontalDragStart: (d) => seekTo(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
                  child: SizedBox(
                    height: 18,
                    child: Center(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.cardElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.border, width: 1.5),
                        ),
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.linear,
                          width: fill.isNaN ? 0 : fill,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          icon,
          size: 20,
          color: accent ? colors.accent : colors.textPrimary,
        ),
      ),
    );
  }
}
