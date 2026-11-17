import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'models.dart';

/// Wraps just_audio + the background/notification service.
/// Plays local files when a track is downloaded, streams otherwise.
///
/// On Android the player is built with an [AudioPipeline] that inserts the
/// platform's native 5-band equalizer and a loudness (gain) enhancer into
/// the audio graph - the same idea as Spotify's built-in EQ.
class PlayerService extends ChangeNotifier {
  PlayerService(this._app) {
    if (hasEqualizer) {
      androidEqualizer = AndroidEqualizer();
      loudnessEnhancer = AndroidLoudnessEnhancer();
      player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [androidEqualizer!, loudnessEnhancer!],
        ),
      );
    } else {
      player = AudioPlayer();
    }
  }

  final AppState _app;
  late final AudioPlayer player;

  /// Only Android exposes just_audio's native effects; web has no such
  /// audio-graph hook (it would need a full Web Audio pipeline).
  static bool get hasEqualizer =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidEqualizer? androidEqualizer;
  AndroidLoudnessEnhancer? loudnessEnhancer;

  List<Track> _queue = [];
  bool get hasTrack => _queue.isNotEmpty;

  /// The track at the current playback position. Looked up through the
  /// player's *sequence*, so it stays correct even when shuffle reorders
  /// the underlying playlist.
  Track? get current {
    final i = player.currentIndex;
    final seq = player.sequence;
    if (i == null || seq == null || i >= seq.length) {
      return i != null && i < _queue.length ? _queue[i] : null;
    }
    final tag = seq[i].tag;
    if (tag is MediaItem) {
      final id = int.tryParse(tag.id);
      if (id != null) return _app.trackById(id);
    }
    return i < _queue.length ? _queue[i] : null;
  }

  bool get playing => player.playing;

  // ------------------------------------------------------------- controls

  Future<void> playQueue(List<Track> queue, {int start = 0}) async {
    if (queue.isEmpty) return;
    _queue = queue;

    final sources = <AudioSource>[];
    for (final t in queue) {
      final localPath = _app.downloadedPath(t.id);
      final Uri uri;
      final Map<String, String>? headers;
      if (localPath != null) {
        uri = Uri.file(localPath);
        headers = null;
      } else if (kIsWeb) {
        // browsers can't attach custom headers to <audio> requests
        final base = _app.api.streamUrl(t.id);
        final token = _app.api.token ?? "";
        uri = Uri.parse("$base?token=$token");
        headers = null;
      } else {
        uri = Uri.parse(_app.api.streamUrl(t.id));
        headers = _app.api.headers;
      }
      sources.add(
        AudioSource.uri(
          uri,
          headers: headers,
          tag: _mediaItem(t),
        ),
      );
    }

    final concat = ConcatenatingAudioSource(children: sources);
    await player.setAudioSource(
      concat,
      initialIndex: start.clamp(0, queue.length - 1),
      initialPosition: Duration.zero,
    );
    await player.play();
    notifyListeners();
  }

  MediaItem _mediaItem(Track t) {
    final album = _app.albumOf(t);
    return MediaItem(
      id: "${t.id}",
      title: t.title,
      artist: t.artist,
      album: album?.name,
      duration: t.duration != null && t.duration! > 0
          ? Duration(milliseconds: (t.duration! * 1000).round())
          : null,
      artUri: _app.api.coverUriWithToken(t.albumId),
    );
  }

  Future<void> toggle() async {
    if (!hasTrack) return;
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> next() async => player.seekToNext();
  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => player.seek(d);

  // ------------------------------------------------------- shuffle/repeat

  bool get shuffleEnabled => player.shuffleModeEnabled;

  Future<void> toggleShuffle() async {
    await player.setShuffleModeEnabled(!player.shuffleModeEnabled);
    notifyListeners();
  }

  LoopMode get repeatMode => player.loopMode;

  /// off -> repeat all -> repeat one -> off
  Future<void> cycleRepeat() async {
    final next = switch (player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      _ => LoopMode.off,
    };
    await player.setLoopMode(next);
    notifyListeners();
  }

  // -------------------------------------------------------- equalizer api

  /// Band parameters (frequencies + gain limits), or null when unavailable.
  Future<AndroidEqualizerParameters?> eqParameters() async {
    final eq = androidEqualizer;
    if (eq == null) return null;
    try {
      return await eq.parameters.timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  /// Persists EQ state so your sound survives app restarts.
  Future<void> saveEq({
    required List<double> gains,
    required double boostDb,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "eq_state",
      jsonEncode({
        "gains": gains,
        "boost": boostDb,
      }),
    );
  }

  Future<Map<String, dynamic>?> _loadEq() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("eq_state");
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Applies the saved EQ once the platform reports its band parameters.
  Future<void> restoreEq() async {
    if (!hasEqualizer) return;
    final saved = await _loadEq();
    if (saved == null) return;
    final params = await eqParameters();
    if (params == null) return;

    final gains = (saved["gains"] as List?)?.cast<num>() ?? const [];
    final n = gains.length < params.bands.length
        ? gains.length
        : params.bands.length;
    for (var i = 0; i < n; i++) {
      final g = gains[i].toDouble();
      if (g >= params.minDecibels && g <= params.maxDecibels) {
        await params.bands[i].setGain(g);
      }
    }
    final boost = (saved["boost"] as num?)?.toDouble() ?? 0.0;
    await loudnessEnhancer?.setTargetGain(boost);
  }

  // ------------------------------------------------------------- wiring

  /// Must be called once after construction.
  void init() {
    player.playerStateStream.listen((_) => notifyListeners());
    player.currentIndexStream.listen((_) => notifyListeners());
    player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        // e.g. server unreachable while streaming
        debugPrint("playback error: $e");
        notifyListeners();
      },
    );
    // ignore: unawaited_futures
    restoreEq();
  }
}
