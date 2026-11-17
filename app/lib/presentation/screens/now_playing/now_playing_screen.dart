import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/core.dart';
import '../../../data/models/models.dart';
import '../../../domain/audio/audio_player_service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/equalizer_bars.dart';

/// Updates the small clock in the top bar. Broadcast so repeated rebuilds can
/// resubscribe safely.
final Stream<DateTime> _clock = Stream<DateTime>.periodic(
  const Duration(seconds: 30),
  (_) => DateTime.now(),
).asBroadcastStream();

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final audio = ref.watch(audioPlayerServiceProvider);
    final snap = ref.watch(audioSnapshotProvider).asData?.value ?? audio.state;
    final track = snap.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: GridBackground(
          child: SafeArea(
            child: Center(
              child: PixelCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsBold.musicNotesSimple,
                        size: 40, color: colors.textSecondary),
                    const SizedBox(height: 12),
                    Text('Nothing playing', style: AppTypography.title()),
                    const SizedBox(height: 12),
                    PixelButton.label(
                      label: 'GO BACK',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 320) {
            HapticFeedback.selectionClick();
            Navigator.of(context).maybePop();
          }
        },
        child: GridBackground(
          child: SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              if (wide) {
                return _WideLayout(track: track, snap: snap, audio: audio);
              }
              return _PhoneLayout(track: track, snap: snap, audio: audio);
            }),
          ),
        ),
      ),
    );
  }
}

/// Narrow layout: everything scrolls in one column and the queue is always
/// visible at the bottom. No tabs, no cover art, no spinning anything.
class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({
    required this.track,
    required this.snap,
    required this.audio,
  });

  final Track track;
  final AudioPlayerSnapshot snap;
  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(track: track, snap: snap),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _SignalCard(track: track, snap: snap),
              const SizedBox(height: 14),
              _StatStrip(snap: snap),
              const SizedBox(height: 14),
              _SeekBar(snap: snap, audio: audio),
              const SizedBox(height: 12),
              _Controls(snap: snap, audio: audio),
              const SizedBox(height: 20),
              _QueuePanel(snap: snap, audio: audio, fillHeight: false),
            ],
          ),
        ),
      ],
    );
  }
}

/// Wide layout: playback on the left, the full queue on the right.
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.track,
    required this.snap,
    required this.audio,
  });

  final Track track;
  final AudioPlayerSnapshot snap;
  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(track: track, snap: snap),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SignalCard(track: track, snap: snap),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              children: [
                                _StatStrip(snap: snap),
                                const SizedBox(height: 14),
                                _SeekBar(snap: snap, audio: audio),
                                const SizedBox(height: 12),
                                _Controls(snap: snap, audio: audio),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _QueuePanel(snap: snap, audio: audio, fillHeight: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.track, required this.snap});

  final Track track;
  final AudioPlayerSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final session = ref.watch(backendSessionProvider);
    final downloaded = ref.watch(downloadsProvider).asData?.value ?? const [];
    final realId = session?.repository.realIdForPixelTrack(track.id);
    final isDownloaded = realId != null &&
        downloaded.any((item) => item.trackId == realId);

    Future<void> download() async {
      final service = ref.read(downloadServiceProvider);
      final id = ref
          .read(backendSessionProvider)
          ?.repository
          .realIdForPixelTrack(track.id);
      if (service == null || id == null || !service.supportsDownloads) return;
      try {
        await service.download(
          trackId: id,
          title: track.title,
          artist: track.artist,
          album: track.album,
          artUrl: track.albumArtUrl,
          duration: track.duration,
          ext: track.ext,
        );
        ref.invalidate(downloadsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved for offline playback')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e')),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          PixelButton.icon(
            icon: PhosphorIconsBold.caretDown,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).maybePop();
            },
            size: 40,
            iconSize: 20,
            tooltip: 'Collapse',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('user@aesthetic ~ \$ now_playing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.prompt(color: colors.green)),
                const SizedBox(height: 2),
                if (snap.error != null)
                  Text(snap.error!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(color: colors.red))
                else
                  Text(track.album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EqualizerBars(active: snap.playing, width: 24, height: 18, barCount: 4),
          const SizedBox(width: 10),
          PixelButton.icon(
            icon: isDownloaded
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsFill.downloadSimple,
            onTap: isDownloaded ? null : download,
            size: 40,
            iconSize: 20,
            iconColor: isDownloaded ? colors.green : colors.cyan,
            borderColor: isDownloaded ? colors.green : colors.border,
            tooltip: isDownloaded ? 'Downloaded' : 'Download offline',
          ),
          const SizedBox(width: 8),
          const _ClockChip(),
        ],
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<DateTime>(
      stream: _clock,
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final time =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border, width: 2),
          ),
          child: Text(time,
              style: AppTypography.mono(
                size: 11,
                color: colors.yellow,
                weight: FontWeight.w700,
              )),
        );
      },
    );
  }
}

/// Replaces the old spinning cover art. A signal-monitor style panel driven by
/// the real playback state: blocky spectrum, live status, track identity.
class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.track, required this.snap});

  final Track track;
  final AudioPlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = snap.queue.length;
    return PixelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsBold.waveform, size: 15, color: colors.cyan),
              const SizedBox(width: 8),
              Text('> signal.monitor',
                  style: AppTypography.prompt(color: colors.cyan)),
              const Spacer(),
              _StatusChip(playing: snap.playing),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title(color: colors.textPrimary)
                .copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            '${track.artist}  •  ${track.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(),
          ),
          const SizedBox(height: 16),
          _SpectrumMonitor(playing: snap.playing, progress: snap.progress),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                total == 0
                    ? 'QUEUE --'
                    : 'TRACK ${snap.currentIndex + 1} / $total',
                style: AppTypography.caption(color: colors.purple),
              ),
              const Spacer(),
              if (track.ext.isNotEmpty)
                Text(track.ext.replaceFirst('.', '').toUpperCase(),
                    style: AppTypography.label(color: colors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = playing ? colors.green : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: playing
            ? colors.green.withValues(alpha: 0.14)
            : colors.cardElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        playing ? '● LIVE' : '❚❚ PAUSED',
        style: AppTypography.label(color: color),
      ),
    );
  }
}

/// Blocky equalizer over a faint monitor grid. No album images anywhere.
class _SpectrumMonitor extends StatelessWidget {
  const _SpectrumMonitor({required this.playing, required this.progress});

  final bool playing;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final head = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 24).clamp(60.0, 900.0);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MonitorGridPainter(
                  line: colors.border.withValues(alpha: 0.35),
                  head: head,
                  headColor: colors.accent.withValues(alpha: 0.5),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: EqualizerBars(
                    active: playing,
                    barCount: 16,
                    width: width,
                    height: 68,
                    gap: 3,
                    colors: colors.accentCycle,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _MonitorGridPainter extends CustomPainter {
  const _MonitorGridPainter({
    required this.line,
    required this.head,
    required this.headColor,
  });

  final Color line;
  final double head;
  final Color headColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final x = size.width * head;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = headColor);
  }

  @override
  bool shouldRepaint(covariant _MonitorGridPainter old) =>
      old.line != line || old.head != head || old.headColor != headColor;
}

/// Useful at-a-glance numbers that replace the old decorative art space.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.snap});

  final AudioPlayerSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final left = snap.duration - snap.position;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'ELAPSED',
            value: _fmt(snap.position),
            color: colors.cyan,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'REMAINING',
            value: _fmt(left > Duration.zero ? left : Duration.zero),
            color: colors.purple,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'IN QUEUE',
            value: snap.queue.isEmpty
                ? '--'
                : '${snap.currentIndex + 1}/${snap.queue.length}',
            color: colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      radius: 10,
      shadowOffset: const Offset(3, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label(color: colors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.mono(
                size: 14,
                color: color,
                weight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.snap, required this.audio});

  final AudioPlayerSnapshot snap;
  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pos = snap.position;
    final dur = snap.duration;
    final maxMs = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
    final value = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: colors.accent,
            inactiveTrackColor: colors.cardElevated,
            thumbColor: colors.cyan,
            overlayColor: colors.cyan.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: value,
            max: maxMs,
            onChanged: (v) => audio.seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(pos), style: AppTypography.caption()),
              Text(_fmt(dur), style: AppTypography.caption()),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.snap, required this.audio});

  final AudioPlayerSnapshot snap;
  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PixelButton.icon(
          icon: PhosphorIconsBold.shuffle,
          onTap: () => audio.toggleShuffle(),
          size: 42,
          iconSize: 18,
          selected: snap.shuffle,
          iconColor: snap.shuffle ? colors.accent : colors.textSecondary,
          borderColor: snap.shuffle ? colors.accent : colors.border,
          tooltip: 'Shuffle',
        ),
        const SizedBox(width: 10),
        PixelButton.icon(
          icon: PhosphorIconsBold.skipBack,
          onTap: () => audio.previous(),
          size: 48,
          iconSize: 22,
          tooltip: 'Previous',
        ),
        const SizedBox(width: 12),
        PixelButton.icon(
          icon: snap.playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
          onTap: () => audio.togglePlayPause(),
          size: 64,
          iconSize: 28,
          color: colors.cardElevated,
          borderColor: colors.accent,
          iconColor: colors.accent,
          shadowOffset: const Offset(5, 5),
          tooltip: snap.playing ? 'Pause' : 'Play',
        ),
        const SizedBox(width: 12),
        PixelButton.icon(
          icon: PhosphorIconsBold.skipForward,
          onTap: () => audio.next(),
          size: 48,
          iconSize: 22,
          tooltip: 'Next',
        ),
        const SizedBox(width: 10),
        PixelButton.icon(
          icon: snap.repeatMode == RepeatMode.one
              ? PhosphorIconsBold.repeatOnce
              : PhosphorIconsBold.repeat,
          onTap: () => audio.cycleRepeat(),
          size: 42,
          iconSize: 18,
          selected: snap.repeatMode != RepeatMode.off,
          iconColor: snap.repeatMode != RepeatMode.off
              ? colors.accent
              : colors.textSecondary,
          borderColor: snap.repeatMode != RepeatMode.off
              ? colors.accent
              : colors.border,
          tooltip: 'Repeat',
        ),
      ],
    );
  }
}

/// Queue is the only bottom section now. No QUEUE/LYRICS tab switch.
class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.snap,
    required this.audio,
    required this.fillHeight,
  });

  final AudioPlayerSnapshot snap;
  final AudioPlayerService audio;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final queue = snap.queue;
    final list = _QueueList(
      snap: snap,
      audio: audio,
      shrinkWrap: !fillHeight,
    );

    return PixelCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsBold.listBullets, size: 15, color: colors.purple),
              const SizedBox(width: 8),
              Text('QUEUE', style: AppTypography.title(color: colors.purple)),
              const SizedBox(width: 8),
              Text('${queue.length} TRACKS',
                  style: AppTypography.caption()),
              const Spacer(),
              if (snap.shuffle)
                Text('SHUFFLE', style: AppTypography.label(color: colors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          if (fillHeight) Expanded(child: list) else list,
        ],
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.snap,
    required this.audio,
    required this.shrinkWrap,
  });

  final AudioPlayerSnapshot snap;
  final AudioPlayerService audio;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final queue = snap.queue;
    if (queue.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Queue is empty', style: AppTypography.caption()),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: queue.length,
      itemBuilder: (context, i) {
        final t = queue[i];
        final active = i == snap.currentIndex;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              audio.playQueue(queue, startIndex: i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: active ? colors.cardElevated : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? colors.accent
                      : colors.border.withValues(alpha: 0.0),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: active
                        ? EqualizerBars(
                            active: snap.playing,
                            width: 20,
                            height: 15,
                            barCount: 3,
                          )
                        : Text('${i + 1}',
                            style: AppTypography.caption()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            color: active ? colors.accent : colors.textPrimary,
                          ),
                        ),
                        Text(t.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption()),
                      ],
                    ),
                  ),
                  if (active)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('NOW',
                          style: AppTypography.label(color: colors.green)),
                    ),
                  Text(_fmt(t.duration), style: AppTypography.caption()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
