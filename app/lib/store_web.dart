// Web implementation: the library is cached in browser storage.
// Offline song downloads are not possible in a browser (no private
// filesystem), so the app streams over HTTP instead.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'store_base.dart';

class WebStore extends Store {
  static const _libraryKey = "musiclab_library";

  @override
  bool get supportsDownloads => false;

  @override
  Future<Map<String, dynamic>?> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_libraryKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLibrary(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_libraryKey, jsonEncode(json));
  }

  @override
  Future<Map<String, dynamic>> loadDownloads() async => {};

  @override
  Future<void> saveDownloads(Map<String, dynamic> json) async {}

  @override
  Future<String> newOfflinePath(String ext) async =>
      throw UnsupportedError("Downloads are not supported on the web");

  @override
  Future<int> writeAll(
    String path,
    Stream<List<int>> stream, {
    void Function(int received)? onChunk,
  }) async =>
      throw UnsupportedError("Downloads are not supported on the web");

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_libraryKey);
  }
}

Store createStore() => WebStore();
