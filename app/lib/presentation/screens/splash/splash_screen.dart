import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/core.dart';
import '../../providers/session_actions.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final List<String> _lines = const [
    '[ OK ] mounting /dev/aesthetic',
    '[ OK ] loading tokyo-night palette',
    '[ OK ] syncing pixel grid renderer',
    '[ OK ] initializing audio pipeline',
    '[ .. ] restoring session / library',
    '[ .. ] launching music-lab shell',
  ];
  int _visible = 0;
  Timer? _tick;
  Timer? _nav;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 320), (t) {
      if (!mounted) return;
      if (_visible < _lines.length) {
        setState(() => _visible++);
      } else {
        t.cancel();
        setState(() => _done = true);
        _nav = Timer(const Duration(milliseconds: 500), () {
          unawaited(_tryRestore());
        });
      }
    });
  }

  Future<void> _tryRestore() async {
    final session = await restoreSession(ref);
    if (!mounted) return;
    if (session != null) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  void _go() {
    // Skip animation: still attempt restore quickly.
    _tick?.cancel();
    _nav?.cancel();
    unawaited(_tryRestore());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _nav?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = _lines.isEmpty ? 0.0 : _visible / _lines.length;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: GridBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Center(
                    child: Column(
                      children: [
                        Animate(
                          onPlay: (c) => c.repeat(reverse: true),
                          effects: const [
                            ScaleEffect(
                              begin: Offset(0.98, 0.98),
                              end: Offset(1.02, 1.02),
                              duration: Duration(milliseconds: 1200),
                              curve: Curves.easeInOut,
                            ),
                          ],
                          child: RingProgress(
                            value: progress.clamp(0.0, 1.0),
                            size: 140,
                            strokeWidth: 12,
                            color: colors.accent,
                            trackColor: colors.cardElevated,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.card,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: colors.border, width: 3),
                              ),
                              child: Icon(
                                PhosphorIconsFill.musicNotes,
                                color: colors.accent,
                                size: 42,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'MUSIC LAB',
                          style: AppTypography.title(color: colors.textPrimary)
                              .copyWith(fontSize: 18, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Text('rice desktop / tokyo night pixel',
                            style: AppTypography.caption(color: colors.purple)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  PixelCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('boot sequence — v0.1.0-pixel',
                            style: AppTypography.prompt(color: colors.green)),
                        const SizedBox(height: 10),
                        ...List.generate(_visible, (i) {
                          final line = _lines[i];
                          final isLast = i == _lines.length - 1;
                          final color = line.startsWith('[ OK ]')
                              ? colors.green
                              : (isLast && !_done ? colors.yellow : colors.cyan);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              line,
                              style: AppTypography.mono(
                                  size: 12, color: color, height: 1.35),
                            ),
                          ).animate().fadeIn(duration: 140.ms).slideX(
                                begin: -0.03,
                                end: 0,
                                duration: 180.ms,
                                curve: Curves.easeOut,
                              );
                        }),
                        if (_done)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('> welcome, listener.',
                                    style: AppTypography.mono(
                                        size: 12,
                                        color: colors.accent,
                                        weight: FontWeight.w700))
                                .animate()
                                .fadeIn(duration: 160.ms),
                          ),
                        const SizedBox(height: 12),
                        _BootProgress(value: progress, done: _done),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text('tap anywhere to skip',
                        style: AppTypography.caption()),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootProgress extends StatelessWidget {
  const _BootProgress({required this.value, required this.done});
  final double value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(builder: (context, c) {
      final fill = (c.maxWidth * value.clamp(0.0, 1.0));
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border, width: 2),
        ),
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: fill,
          decoration: BoxDecoration(
            color: done ? colors.green : colors.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    });
  }
}
