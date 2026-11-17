/// Platform-neutral storage contract. Implemented separately for
/// phones/desktop (dart:io) and web (SharedPreferences).
abstract class Store {
  /// Whether offline song downloads are possible on this platform.
  bool get supportsDownloads;

  Future<Map<String, dynamic>?> loadLibrary();
  Future<void> saveLibrary(Map<String, dynamic> json);

  Future<Map<String, dynamic>> loadDownloads();
  Future<void> saveDownloads(Map<String, dynamic> json);

  /// A filesystem path where a downloaded song should be written.
  Future<String> newOfflinePath(String ext);

  /// Writes a byte stream to [path], reporting cumulative bytes received.
  Future<int> writeAll(
    String path,
    Stream<List<int>> stream, {
    void Function(int received)? onChunk,
  });

  Future<void> deleteFile(String path);

  Future<void> clear();
}
