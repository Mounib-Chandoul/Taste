import 'dart:async';
import 'dart:math';

import '../../data/models/track.dart';
import 'audio_player_service.dart';

/// Simulated player for UI development and mock-data mode.
class MockAudioPlayerService implements AudioPlayerService {
  MockAudioPlayerService() {
    _controller = StreamController<AudioPlayerSnapshot>.broadcast(
      onListen: () => _controller.add(_state),
    );
  }

  late final StreamController<AudioPlayerSnapshot> _controller;
  AudioPlayerSnapshot _state = const AudioPlayerSnapshot();
  Timer? _ticker;
  final _rand = Random();

  @override
  Stream<AudioPlayerSnapshot> get stream => _controller.stream;

  @override
  AudioPlayerSnapshot get state => _state;

  void _emit(AudioPlayerSnapshot next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(_state);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_state.playing || _state.currentTrack == null) return;
      final nextPos = _state.position + const Duration(milliseconds: 250);
      if (nextPos >= _state.duration && _state.duration > Duration.zero) {
        _handleComplete();
      } else {
        _emit(_state.copyWith(position: nextPos));
      }
    });
  }

  void _handleComplete() {
    if (_state.repeatMode == RepeatMode.one) {
      _emit(_state.copyWith(position: Duration.zero, playing: true));
      return;
    }
    if (_state.currentIndex < _state.queue.length - 1) {
      unawaited(next());
      return;
    }
    if (_state.repeatMode == RepeatMode.all && _state.queue.isNotEmpty) {
      unawaited(playQueue(_state.queue, startIndex: 0));
      return;
    }
    _emit(_state.copyWith(playing: false, position: _state.duration));
  }

  @override
  Future<void> playTrack(Track track, {List<Track>? queue, int? index}) async {
    final q = queue ?? [track];
    final i = index ?? q.indexWhere((t) => t.id == track.id);
    _emit(_state.copyWith(
      currentTrack: track,
      queue: q,
      currentIndex: i < 0 ? 0 : i,
      position: Duration.zero,
      duration: track.duration,
      playing: true,
    ));
    _startTicker();
  }

  @override
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final idx = startIndex.clamp(0, tracks.length - 1);
    await playTrack(tracks[idx], queue: tracks, index: idx);
  }

  @override
  Future<void> togglePlayPause() async {
    if (_state.currentTrack == null) return;
    if (_state.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  @override
  Future<void> pause() async {
    _emit(_state.copyWith(playing: false));
  }

  @override
  Future<void> resume() async {
    if (_state.currentTrack == null) return;
    _emit(_state.copyWith(playing: true));
    _startTicker();
  }

  @override
  Future<void> seek(Duration position) async {
    final d = _state.duration;
    var p = position;
    if (p < Duration.zero) p = Duration.zero;
    if (d > Duration.zero && p > d) p = d;
    _emit(_state.copyWith(position: p));
  }

  @override
  Future<void> next() async {
    final q = _state.queue;
    if (q.isEmpty) return;
    if (_state.shuffle) {
      final idx = _rand.nextInt(q.length);
      await playQueue(q, startIndex: idx);
      return;
    }
    final nextIdx = _state.currentIndex + 1;
    if (nextIdx < q.length) {
      await playQueue(q, startIndex: nextIdx);
    } else if (_state.repeatMode == RepeatMode.all) {
      await playQueue(q, startIndex: 0);
    }
  }

  @override
  Future<void> previous() async {
    if (_state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final q = _state.queue;
    if (q.isEmpty) return;
    final prevIdx = _state.currentIndex - 1;
    if (prevIdx >= 0) {
      await playQueue(q, startIndex: prevIdx);
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> toggleShuffle() async {
    _emit(_state.copyWith(shuffle: !_state.shuffle));
  }

  @override
  Future<void> cycleRepeat() async {
    final nextMode = switch (_state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    _emit(_state.copyWith(repeatMode: nextMode));
  }

  @override
  Future<void> setVolume(double volume) async {
    _emit(_state.copyWith(volume: volume.clamp(0.0, 1.0)));
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _controller.close();
  }
}
