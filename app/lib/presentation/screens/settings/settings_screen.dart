import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/core.dart';
import '../../providers/app_providers.dart';
import '../../providers/session_actions.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _quality = 'High (320 kbps)';
  bool _eqEnabled = true;
  final List<double> _bands = [0.2, 0.4, 0.6, 0.5, 0.3, 0.45];
  int? _sleepMinutes; // null = off
  Timer? _sleepTimer;
  int? _sleepRemainingSec;

  static const _qualities = [
    'Low (96 kbps)',
    'Normal (160 kbps)',
    'High (320 kbps)',
    'Lossless (FLAC)',
  ];

  static const _sleepOptions = <int?>[null, 15, 30, 45, 60];

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _setSleep(int? minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepMinutes = minutes;
      _sleepRemainingSec = minutes == null ? null : minutes * 60;
    });
    if (minutes == null) return;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = (_sleepRemainingSec ?? 0) - 1;
      if (left <= 0) {
        t.cancel();
        setState(() {
          _sleepRemainingSec = 0;
          _sleepMinutes = null;
        });
      } else {
        setState(() => _sleepRemainingSec = left);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = ref.watch(accentColorProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('user@aesthetic ~ \$ settings',
              style: AppTypography.prompt(color: colors.green)),
          const SizedBox(height: 4),
          Text('tweak the rice. changes apply live.',
              style: AppTypography.caption()),
          const SizedBox(height: 16),

          _Section(
            title: 'THEME ACCENT',
            prompt: 'theme --accent',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick an accent color (live preview).',
                    style: AppTypography.caption()),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in colors.accentCycle)
                      _AccentSwatch(
                        color: c,
                        selected: accent == c,
                        onTap: () =>
                            ref.read(accentColorProvider.notifier).state = c,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colors.border, width: 2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('active accent applied to theme',
                        style: AppTypography.caption(color: accent)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _Section(
            title: 'AUDIO QUALITY',
            prompt: 'audio --quality',
            child: Column(
              children: [
                for (final q in _qualities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PixelCard(
                      onTap: () => setState(() => _quality = q),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      radius: 12,
                      shadowOffset: const Offset(3, 3),
                      color: _quality == q ? colors.cardElevated : colors.card,
                      borderColor:
                          _quality == q ? accent : colors.border,
                      child: Row(
                        children: [
                          Icon(
                            _quality == q
                                ? PhosphorIconsFill.radioButton
                                : PhosphorIconsRegular.circle,
                            color: _quality == q
                                ? accent
                                : colors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(q,
                                style: AppTypography.body(
                                  color: _quality == q
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                                )),
                          ),
                          if (q.startsWith('Lossless'))
                            Text('HI-FI',
                                style: AppTypography.label(color: colors.yellow)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _Section(
            title: 'EQUALIZER',
            prompt: 'audio --eq ${_eqEnabled ? "on" : "off"}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('5-band EQ (mock)',
                          style: AppTypography.caption()),
                    ),
                    PixelButton.label(
                      label: _eqEnabled ? 'ON' : 'OFF',
                      selected: _eqEnabled,
                      color: _eqEnabled ? colors.cardElevated : colors.card,
                      borderColor: _eqEnabled ? accent : colors.border,
                      textColor: _eqEnabled ? accent : colors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      onTap: () => setState(() => _eqEnabled = !_eqEnabled),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: _eqEnabled ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !_eqEnabled,
                    child: _EqBands(
                      values: _bands,
                      color: accent,
                      onChanged: (i, v) =>
                          setState(() => _bands[i] = v.clamp(0.0, 1.0)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final label in const ['60', '230', '910', '3k', '14k', ''])
                      if (label.isNotEmpty)
                        Text(label, style: AppTypography.caption()),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _Section(
            title: 'SLEEP TIMER',
            prompt: 'timer --sleep',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stop playback after a set duration (mock).',
                    style: AppTypography.caption()),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _sleepOptions)
                      PixelButton.label(
                        label: m == null ? 'OFF' : '${m}m',
                        selected: _sleepMinutes == m,
                        color: _sleepMinutes == m
                            ? colors.cardElevated
                            : colors.card,
                        borderColor:
                            _sleepMinutes == m ? accent : colors.border,
                        textColor: _sleepMinutes == m
                            ? accent
                            : colors.textSecondary,
                        onTap: () => _setSleep(m),
                      ),
                  ],
                ),
                if (_sleepRemainingSec != null) ...[
                  const SizedBox(height: 12),
                  PixelCard(
                    padding: const EdgeInsets.all(12),
                    radius: 10,
                    shadowOffset: const Offset(3, 3),
                    color: colors.cardElevated,
                    borderColor: accent,
                    child: Row(
                      children: [
                        Icon(PhosphorIconsFill.timer,
                            color: accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _sleepRemainingSec == 0
                                ? 'Timer ended (mock pause).'
                                : 'Stopping in ${_fmtRemaining(_sleepRemainingSec!)}',
                            style: AppTypography.body(color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          _Section(
            title: 'ACCOUNT / SESSION',
            prompt: 'whoami && session --status',
            child: Builder(builder: (context) {
              final session = ref.watch(backendSessionProvider);
              final username = ref.watch(pixelUsernameProvider);
              final connected = session != null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signed in as: $username',
                      style: AppTypography.body(color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    connected
                        ? 'Backend: ${session.api.base}'
                        : 'Mode: demo / mock data',
                    style: AppTypography.caption(
                        color: connected ? colors.green : colors.yellow),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PixelButton.label(
                          label: connected ? 'DISCONNECT' : 'SWITCH / LOGIN',
                          color: colors.cardElevated,
                          borderColor: connected ? colors.red : accent,
                          textColor: connected ? colors.red : accent,
                          onTap: () async {
                            await signOut(ref);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'ABOUT',
            prompt: 'cat ./about.txt',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Music Lab — Pixel Front End',
                    style: AppTypography.title()),
                const SizedBox(height: 6),
                Text(
                  'Rice Desktop / Tokyo Night Pixel aesthetic.\n'
                  'Mock data + repository/service interfaces (Riverpod, go_router). '
                  'Supports demo mode and real Music Lab backend sessions.',
                  style: AppTypography.caption(),
                ),
                const SizedBox(height: 8),
                Text('v0.1.0-pixel', style: AppTypography.caption(color: accent)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static String _fmtRemaining(int sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.prompt, required this.child});
  final String title;
  final String prompt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PixelCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt, style: AppTypography.prompt(color: colors.cyan)),
          const SizedBox(height: 6),
          Text(title, style: AppTypography.label(color: colors.textSecondary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch(
      {required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.textPrimary : colors.border,
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.hardShadow,
              offset: selected ? Offset.zero : const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        transform: selected
            ? Matrix4.translationValues(4.0, 4.0, 0.0)
            : Matrix4.identity(),
        child: selected
            ? Icon(PhosphorIconsBold.check, color: colors.card, size: 20)
            : null,
      ),
    );
  }
}

class _EqBands extends StatelessWidget {
  const _EqBands(
      {required this.values, required this.color, required this.onChanged});
  final List<double> values;
  final Color color;
  final void Function(int index, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final h = c.maxHeight;
                        final fillH = (values[i] * h).clamp(8.0, h);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _setFromDy(d.localPosition.dy, h, i),
                          onVerticalDragUpdate: (d) =>
                              _setFromDy(d.localPosition.dy, h, i),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.cardElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border, width: 2),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: fillH,
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _setFromDy(double dy, double h, int i) {
    final v = 1 - (dy / h);
    onChanged(i, v.clamp(0.0, 1.0));
  }
}
