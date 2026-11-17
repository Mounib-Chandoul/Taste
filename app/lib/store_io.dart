import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'store_base.dart';

class IOStore extends Store {
  @override
  bool get supportsDownloads => true;

  Future<Directory> _dataDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory("${docs.path}/musiclab_data").create(recursive: true);
  }

  Future<Directory> _offlineDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory("${docs.path}/musiclab_offline").create(recursive: true);
  }

  Future<File> _file(String name) async =>
      File("${(await _dataDir()).path}/$name");

  @override
  Future<void> saveLibrary(Map<String, dynamic> json) async =>
      _file("library.json").then((f) => f.writeAsString(jsonEncode(json)));

  @override
  Future<Map<String, dynamic>?> loadLibrary() async {
    final f = await _file("library.json");
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDownloads(Map<String, dynamic> json) async =>
      _file("downloads.json").then((f) => f.writeAsString(jsonEncode(json)));

  @override
  Future<Map<String, dynamic>> loadDownloads() async {
    final f = await _file("downloads.json");
    if (!await f.exists()) return {};
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<String> newOfflinePath(String ext) async {
    final dir = await _offlineDir();
    return "${dir.path}/offline_${DateTime.now().microsecondsSinceEpoch}$ext";
  }

  @override
  Future<int> writeAll(
    String path,
    Stream<List<int>> stream, {
    void Function(int received)? onChunk,
  }) async {
    final sink = File(path).openWrite();
    var received = 0;
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        onChunk?.call(received);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return received;
  }

  @override
  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> clear() async {
    final f = await _file("library.json");
    if (await f.exists()) await f.delete();
    final d = await _file("downloads.json");
    if (await d.exists()) await d.delete();
    final dir = await _offlineDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

Store createStore() => IOStore();
