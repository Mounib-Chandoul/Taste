// Bottom sheet with the Android equalizer: one slider per frequency band,
// preset curves, and a loudness (volume boost) fader.
//
// Presets are defined as 5-point gain curves. Devices expose different
// band counts, so we linearly *interpolate* the curve across whatever
// bands exist - same math as resampling a waveform.

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../player_service.dart';

/// Bottom sheet with the Android equalizer: one slider per frequency band,
/// preset curves, and a loudness (volume boost) fader.
///
/// Presets are defined as 5-point gain curves. Devices expose different
/// band counts, so we linearly *interpolate* the curve across whatever
/// bands exist - same math as resampling a waveform.

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  static const _presets = <String, List<double>>{
    "Flat": [0, 0, 0, 0, 0],
    "Bass Boost": [6, 4, 1, 0, 0],
    "Treble": [0, 0, 1, 4, 6],
    "Vocal": [-2, 1, 3, 2, -1],
    "Electronic": [5, 2, -1, 2, 4],
    "Rock": [4, 2, -2, 2, 4],
  };

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();

    if (!PlayerService.hasEqualizer) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "The equalizer runs on Android's native audio effect pipeline, "
          "so it lives in the Android app. On the web build the browser "
          "owns the audio graph and doesn't expose one.",
          style: TextStyle(height: 1.4),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<AndroidEqualizerParameters?>(
          future: player.eqParameters(),
          builder: (context, snap) {
            final params = snap.data;
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (params == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "This device didn't expose an equalizer "
                  "(start playback once, then reopen this panel).",
                ),
              );
            }
            return _EqControls(params: params);
          },
        ),
      ),
    );
  }
}

class _EqControls extends StatefulWidget {
  const _EqControls({required this.params});
  final AndroidEqualizerParameters params;

  @override
  State<_EqControls> createState() => _EqControlsState();
}

class _EqControlsState extends State<_EqControls> {
  List<double>? _gains; // live slider values, dB per band
  double _boost = 0;

  @override
  void initState() {
    super.initState();
    _gains = [for (final b in widget.params.bands) b.gain];
    // loudness enhancer's current gain arrives async; start at its value
    final player = context.read<PlayerService>();
    player.loudnessEnhancer?.targetGainStream.first.then((g) {
      if (mounted) setState(() => _boost = g.clamp(-10, 10));
    }).catchError((_) {});
  }

  /// Map an index in [0, n-1] onto a position in the 5-point preset curve.
  double _curveAt(List<double> curve, double t) {
    final pos = t * (curve.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return curve[lo];
    return curve[lo] + (curve[hi] - curve[lo]) * (pos - lo);
  }

  Future<void> _applyPreset(String name) async {
    final player = context.read<PlayerService>();
    final bands = widget.params.bands;
    final curve = EqualizerSheet._presets[name]!;
    final list = <double>[];
    for (var i = 0; i < bands.length; i++) {
      final t = bands.length == 1 ? 0.0 : i / (bands.length - 1);
      final g = _curveAt(curve, t)
          .clamp(widget.params.minDecibels, widget.params.maxDecibels);
      await bands[i].setGain(g);
      list.add(g);
    }
    setState(() => _gains = list);
    await player.saveEq(gains: list, boostDb: _boost);
  }

  String _freqLabel(double hz) =>
      hz >= 1000 ? "${(hz / 1000).toStringAsFixed(1)} kHz" : "${hz.round()} Hz";

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final bands = widget.params.bands;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Equalizer", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final name in EqualizerSheet._presets.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: () => _applyPreset(name),
                    child: Text(name),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < bands.length; i++)
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  _freqLabel(bands[i].centerFrequency),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _gains![i]
                      .clamp(widget.params.minDecibels, widget.params.maxDecibels)
                      .toDouble(),
                  min: widget.params.minDecibels,
                  max: widget.params.maxDecibels,
                  divisions:
                      ((widget.params.maxDecibels - widget.params.minDecibels) *
                              2)
                          .round(),
                  label: "${_gains![i].toStringAsFixed(1)} dB",
                  onChanged: (v) {
                    setState(() => _gains![i] = v);
                    // ignore: discarded_futures
                    bands[i].setGain(v);
                  },
                  onChangeEnd: (v) => player.saveEq(
                    gains: _gains!,
                    boostDb: _boost,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 56,
              child: Text("Boost",
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: Slider(
                value: _boost.clamp(-10, 10).toDouble(),
                min: -10,
                max: 10,
                divisions: 40,
                label: "${_boost.toStringAsFixed(1)} dB",
                onChanged: (v) {
                  setState(() => _boost = v);
                  // ignore: discarded_futures
                  player.loudnessEnhancer?.setTargetGain(v);
                },
                onChangeEnd: (v) =>
                    player.saveEq(gains: _gains!, boostDb: v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
