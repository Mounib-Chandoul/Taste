import 'dart:async';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart'
    show MediaItem;

import '../../data/models/track.dart';
import 'audio_player_service.dart';
import 'playback_source.dart';

/// Real playback backed by `just_audio`.
///
/// The whole queue is installed as a [ja.ConcatenatingAudioSource] so seeking
/// between tracks, Android background playback and gapless-style next/previous
/// all work with one player. Every source carries a `MediaItem` tag because
/// `just_audio_background` requires it.
class JustAudioPlayerService implements AudioPlayerService {
  JustAudioPlayerService({this.sourceResolver, this.uriResolver});

  /// Preferred resolver: supplies the authenticated URL, cover art and tags.
  final FutureOr<PlaybackSource?> Function(Track track)? sourceResolver;

  /// Legacy string-only resolver, kept as a fallback for simple callers.
  final FutureOr<String?> Function(Track track)? uriResolver;

  final ja.AudioPlayer _player = ja.AudioPlayer();
  final _controller = StreamController<AudioPlayerSnapshot>.broadcast();
  AudioPlayerSnapshot _state = const AudioPlayerSnapshot();

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<ja.PlayerState>? _stateSub;
  StreamSubscription<int?>? _indexSub;

  /// Tracks aligned with the player's current sequence (unresolved tracks are
  /// skipped so indices always match what the player actually loaded).
  List<Track> _resolvedTracks = const [];

  bool _wired = false;

  void _ensureWired() {
    if (_wired) return;
    _wired = true;
    _posSub = _player.positionStream.listen((p) {
      _emit(_state.copyWith(position: p));
    });
    _durSub = _player.durationStream.listen((d) {
      if (d != null) _emit(_state.copyWith(duration: d));
    });
    _indexSub = _player.currentIndexStream.listen((i) {
      if (i == null || i < 0 || i >= _resolvedTracks.length) return;
      _emit(_state.copyWith(
        currentTrack: _resolvedTracks[i],
        currentIndex: i,
        position: Duration.zero,
        duration: _resolvedTracks[i].duration,
      ));
    });
    _stateSub = _player.playerStateStream.listen((s) {
      _emit(_state.copyWith(playing: s.playing));
      if (s.processingState == ja.ProcessingState.completed) {
        // The concatenating source handles advancing/wrapping itself. Avoid a
        // manual next() here or tracks would be skipped twice.
        _emit(_state.copyWith(playing: false));
      }
    });
  }

  @override
  Stream<AudioPlayerSnapshot> get stream => _controller.stream;

  @override
  AudioPlayerSnapshot get state => _state;

  void _emit(AudioPlayerSnapshot next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<PlaybackSource?> _resolve(Track track) async {
    final sourceResolver = this.sourceResolver;
    if (sourceResolver != null) return await sourceResolver(track);
    final uriResolver = this.uriResolver;
    if (uriResolver != null) {
      final uri = await uriResolver(track);
      if (uri == null) return null;
      return PlaybackSource(
        uri: Uri.parse(uri),
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
      );
    }
    return null;
  }

  MediaItem _mediaItem(Track track, PlaybackSource source) => MediaItem(
        id: track.id,
        title: source.title.isEmpty ? track.title : source.title,
        artist: source.artist.isEmpty ? track.artist : source.artist,
        album: source.album.isEmpty ? track.album : source.album,
        duration: source.duration ?? track.duration,
        artUri: source.artUri,
      );

  Future<void> _loadQueue(
    List<Track> tracks,
    int index, {
    required bool play,
  }) async {
    final children = <ja.AudioSource>[];
    final resolved = <Track>[];
    _emit(_state.copyWith(clearError: true, playing: false));
    for (final track in tracks) {
      final source = await _resolve(track);
      if (source == null) continue;
      final tag = _mediaItem(track, source);
      final path = source.filePath;
      if (path != null && path.isNotEmpty) {
        children.add(ja.AudioSource.file(path, tag: tag));
      } else {
        children.add(
          ja.AudioSource.uri(
            source.uri,
            headers: source.headers.isEmpty ? null : source.headers,
            tag: tag,
          ),
        );
      }
      resolved.add(track);
    }

    if (children.isEmpty) {
      _resolvedTracks = resolved;
      _emit(_state.copyWith(
        currentTrack: tracks.isEmpty ? null : tracks[index],
        queue: tracks,
        currentIndex: index,
        position: Duration.zero,
        playing: false,
      ));
      return;
    }

    final safeIndex = index < 0
        ? 0
        : (index >= children.length ? children.length - 1 : index);
    _resolvedTracks = resolved;

    try {
      await _player.setAudioSource(
        ja.ConcatenatingAudioSource(
          children: children,
          useLazyPreparation: true,
        ),
        initialIndex: safeIndex,
        initialPosition: Duration.zero,
      );
    } catch (e) {
      // Callers do not await playTrack, so surface load failures in the UI
      // instead of letting them disappear as unhandled async errors.
      _emit(_state.copyWith(
        currentTrack: tracks.isEmpty ? null : tracks[index],
        queue: tracks,
        currentIndex: index,
        position: Duration.zero,
        playing: false,
        error: 'audio load failed (${e.runtimeType}): $e',
      ));
      return;
    }
    await _player.setLoopMode(_loopModeFor(_state.repeatMode));
    await _player.setShuffleModeEnabled(_state.shuffle);

    final current = resolved[safeIndex];
    _emit(_state.copyWith(
      currentTrack: current,
      queue: resolved,
      currentIndex: safeIndex,
      position: Duration.zero,
      duration: current.duration,
      playing: play,
    ));
    if (play) await _player.play();
  }

  static ja.LoopMode _loopModeFor(RepeatMode mode) => switch (mode) {
        RepeatMode.off => ja.LoopMode.off,
        RepeatMode.all => ja.LoopMode.all,
        RepeatMode.one => ja.LoopMode.one,
      };

  @override
  Future<void> playTrack(Track track, {List<Track>? queue, int? index}) async {
    _ensureWired();
    final q = queue ?? [track];
    final requested = index ?? q.indexWhere((t) => t.id == track.id);
    final idx = requested < 0 ? 0 : requested;
    await _loadQueue(q, idx, play: true);
  }

  @override
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final idx = startIndex.clamp(0, tracks.length - 1);
    await playTrack(tracks[idx], queue: tracks, index: idx);
  }

  @override
  Future<void> togglePlayPause() async {
    _ensureWired();
    if (_player.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _emit(_state.copyWith(playing: false));
  }

  @override
  Future<void> resume() async {
    if (_resolvedTracks.isEmpty) return;
    await _player.play();
    _emit(_state.copyWith(playing: true));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> next() async {
    if (_resolvedTracks.isEmpty) return;
    if (_state.repeatMode == RepeatMode.one) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasNext) {
      await _player.seekToNext();
      return;
    }
    if (_state.repeatMode == RepeatMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  @override
  Future<void> previous() async {
    if (_resolvedTracks.isEmpty) return;
    if (_state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> toggleShuffle() async {
    final enabled = !_state.shuffle;
    await _player.setShuffleModeEnabled(enabled);
    _emit(_state.copyWith(shuffle: enabled));
  }

  @override
  Future<void> cycleRepeat() async {
    final mode = switch (_state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    await _player.setLoopMode(_loopModeFor(mode));
    _emit(_state.copyWith(repeatMode: mode));
  }

  @override
  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    await _player.setVolume(v);
    _emit(_state.copyWith(volume: v));
  }

  @override
  Future<void> dispose() async {
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _stateSub?.cancel();
    await _indexSub?.cancel();
    await _player.dispose();
    await _controller.close();
  }
}
