import '../../api.dart';
import '../../store.dart';
import '../models/models.dart';

/// Downloads full audio files to the platform's private offline directory.
///
/// The web build reports `supportsDownloads == false` and never calls this;
/// Android/desktop keep a small JSON manifest alongside the cached bytes.
class DownloadService {
  DownloadService(this.api, this.store);

  final ServerApi api;
  final Store store;

  /// Kept in memory so resolving a 500-track queue does not re-read the
  /// manifest from disk once per track.
  Map<int, DownloadedTrack>? _cache;

  bool get supportsDownloads => store.supportsDownloads;

  Future<Map<int, DownloadedTrack>> load() async {
    final cached = _cache;
    if (cached != null) return Map<int, DownloadedTrack>.from(cached);
    final raw = await store.loadDownloads();
    final result = <int, DownloadedTrack>{};
    raw.forEach((key, value) {
      final id = int.tryParse(key);
      if (id == null || value is! Map) return;
      final info = DownloadedTrack.fromJson(Map<String, dynamic>.from(value));
      if (info.path.isNotEmpty) result[id] = info;
    });
    _cache = result;
    return Map<int, DownloadedTrack>.from(result);
  }

  Future<void> _save(Map<int, DownloadedTrack> items) async {
    await store.saveDownloads({
      for (final entry in items.entries)
        entry.key.toString(): entry.value.toJson(),
    });
    _cache = Map<int, DownloadedTrack>.from(items);
  }

  Future<String?> localPath(int trackId) async {
    final items = await load();
    return items[trackId]?.path;
  }

  Future<bool> isDownloaded(int trackId) async =>
      await localPath(trackId) != null;

  /// Streams [trackId] to disk and records it in the offline manifest.
  Future<DownloadedTrack> download({
    required int trackId,
    required String title,
    required String artist,
    required String album,
    required String artUrl,
    required Duration duration,
    required String ext,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!supportsDownloads) {
      throw UnsupportedError('Offline downloads are not available here');
    }
    final items = await load();
    final existing = items[trackId];
    if (existing != null) return existing;

    final cleanExt = ext.trim().replaceAll('.', '');
    final suffix = cleanExt.isEmpty ? '.mp3' : '.$cleanExt';
    final path = await store.newOfflinePath(suffix);
    try {
      final response = await api.download(trackId);
      final total = response.contentLength ?? 0;
      final received = await store.writeAll(
        path,
        response.stream,
        onChunk: onProgress == null
            ? null
            : (bytes) => onProgress(bytes, total),
      );
      final info = DownloadedTrack(
        trackId: trackId,
        path: path,
        title: title,
        artist: artist,
        album: album,
        artUrl: artUrl,
        duration: duration,
        ext: suffix,
        bytes: received,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );
      items[trackId] = info;
      await _save(items);
      return info;
    } catch (_) {
      await store.deleteFile(path);
      rethrow;
    }
  }

  Future<void> remove(int trackId) async {
    final items = await load();
    final info = items.remove(trackId);
    if (info != null) await store.deleteFile(info.path);
    await _save(items);
  }
}
