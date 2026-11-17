import 'dart:async';

import '../../data/models/track.dart';

enum RepeatMode { off, all, one }

class AudioPlayerSnapshot {
  const AudioPlayerSnapshot({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = -1,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
    this.volume = 0.8,
    this.error,
  });

  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final Duration position;
  final Duration duration;
  final bool playing;
  final bool shuffle;
  final RepeatMode repeatMode;
  final double volume;

  /// Last playback/loading error, shown in the now-playing screen.
  final String? error;

  double get progress {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return 0;
    return (position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  AudioPlayerSnapshot copyWith({
    Track? currentTrack,
    bool clearTrack = false,
    List<Track>? queue,
    int? currentIndex,
    Duration? position,
    Duration? duration,
    bool? playing,
    bool? shuffle,
    RepeatMode? repeatMode,
    double? volume,
    bool clearError = false,
    String? error,
  }) {
    return AudioPlayerSnapshot(
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playing: playing ?? this.playing,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Audio playback contract. Implement with just_audio for real playback or
/// with [MockAudioPlayerService] for UI development without a backend.
abstract class AudioPlayerService {
  Stream<AudioPlayerSnapshot> get stream;
  AudioPlayerSnapshot get state;

  Future<void> playTrack(Track track, {List<Track>? queue, int? index});
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0});
  Future<void> togglePlayPause();
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> toggleShuffle();
  Future<void> cycleRepeat();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
