import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin HTTP client for the Music Lab server.
class ServerApi {
  ServerApi(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) throw ArgumentError("Server address is empty");
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      url = "http://$url";
    }
    while (url.endsWith("/")) {
      url = url.substring(0, url.length - 1);
    }
    base = url;
  }

  late final String base;
  String? token;

  /// Called when any authenticated request returns 401, so the UI can drop
  /// the session and send the user back to login.
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 10);

  Map<String, String> get headers => {
        if (token != null) "Authorization": "Bearer $token",
      };

  Uri _uri(String path) => Uri.parse("$base$path");

  // ---------------------------------------------------------------- calls

  Future<String> login(String username, String password) async {
    final resp = await _client
        .post(
          _uri("/api/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"username": username, "password": password}),
        )
        .timeout(_timeout);
    final body = _decode(resp);
    if (resp.statusCode == 401) {
      throw AuthException("Wrong username or password");
    }
    if (resp.statusCode != 200) {
      throw ServerException("Login failed (${resp.statusCode})");
    }
    final t = body["token"] as String?;
    if (t == null) throw ServerException("Server did not return a token");
    token = t;
    return t;
  }

  Future<void> logout() async {
    final current = token;
    if (current == null || current.isEmpty) return;
    try {
      await _client
          .post(
            _uri('/api/logout'),
            headers: {'Authorization': 'Bearer $current'},
          )
          .timeout(_timeout);
    } catch (_) {
      // A revoked/expired token cannot be revoked again; local cleanup still
      // needs to happen, so callers should not fail on a network error here.
    }
  }

  Future<Map<String, dynamic>> library() async {
    final result = await libraryFetch();
    return result.data ?? <String, dynamic>{};
  }

  /// Full library dump with conditional-request support.
  ///
  /// When [etag] matches the server's current library revision the server
  /// responds 304 and [LibraryFetchResult.notModified] is true, so callers can
  /// keep their cached copy without paying for a JSON re-parse.
  Future<LibraryFetchResult> libraryFetch({String? etag}) async {
    final requestHeaders = <String, String>{...headers};
    if (etag != null && etag.isNotEmpty) {
      requestHeaders['If-None-Match'] = etag;
    }
    final resp = await _client
        .get(_uri("/api/library"), headers: requestHeaders)
        .timeout(_timeout);
    if (resp.statusCode == 304) {
      return LibraryFetchResult(notModified: true, etag: etag);
    }
    _guard(resp);
    return LibraryFetchResult(
      data: _decode(resp),
      etag: resp.headers['etag'] ?? etag,
    );
  }

  Future<Map<String, dynamic>> status() async {
    final resp = await _client
        .get(_uri("/api/status"), headers: headers)
        .timeout(_timeout);
    _guard(resp);
    return _decode(resp);
  }

  Future<void> scan() async {
    final resp = await _client
        .post(_uri("/api/scan"), headers: headers)
        .timeout(_timeout);
    _guard(resp);
  }

  /// Ranked server-side search (FTS5 trigram + BM25 on the server).
  Future<Map<String, dynamic>> search(String query, {int limit = 30}) async {
    final uri = _uri('/api/search').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final resp = await _client.get(uri, headers: headers).timeout(_timeout);
    _guard(resp);
    return _decode(resp);
  }

  Future<List<String>> genres() async {
    final resp = await _client
        .get(_uri('/api/genres'), headers: headers)
        .timeout(_timeout);
    _guard(resp);
    final body = _decode(resp);
    return ((body['genres'] as List?) ?? [])
        .whereType<Map>()
        .map((g) => (g['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> randomTracks({int limit = 20}) async {
    final uri = _uri('/api/random').replace(
      queryParameters: {'limit': '$limit'},
    );
    final resp = await _client.get(uri, headers: headers).timeout(_timeout);
    _guard(resp);
    final body = _decode(resp);
    return ((body['tracks'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  /// Streams the full audio file to a list of byte chunks (for downloads).
  Future<http.StreamedResponse> download(int trackId) async {
    final req = http.Request("GET", _uri("/api/download/$trackId"))
      ..headers.addAll(headers);
    final resp = await _client.send(req).timeout(const Duration(hours: 1));
    if (resp.statusCode == 401) {
      onUnauthorized?.call();
      throw AuthException("Session expired");
    }
    if (resp.statusCode != 200) {
      throw ServerException("Download failed (${resp.statusCode})");
    }
    return resp;
  }

  // ----------------------------------------------------------- playlists

  Future<List<Map<String, dynamic>>> playlists() async {
    final resp = await _client
        .get(_uri("/api/playlists"), headers: headers)
        .timeout(_timeout);
    _guard(resp);
    final body = _decode(resp);
    return ((body["playlists"] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPlaylist(String name) async {
    final resp = await _client
        .post(
          _uri("/api/playlists"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({"name": name}),
        )
        .timeout(_timeout);
    _guard(resp);
    return _decode(resp);
  }

  Future<void> renamePlaylist(int id, String name) async {
    final resp = await _client
        .patch(
          _uri("/api/playlists/$id"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({"name": name}),
        )
        .timeout(_timeout);
    _guard(resp);
  }

  Future<void> deletePlaylist(int id) async {
    final resp = await _client
        .delete(_uri("/api/playlists/$id"), headers: headers)
        .timeout(_timeout);
    _guard(resp);
  }

  Future<void> addToPlaylist(int playlistId, int trackId) async {
    final resp = await _client
        .post(
          _uri("/api/playlists/$playlistId/tracks"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({"track_id": trackId}),
        )
        .timeout(_timeout);
    _guard(resp);
  }

  Future<void> removeFromPlaylist(int playlistId, int trackId) async {
    final resp = await _client
        .delete(
          _uri("/api/playlists/$playlistId/tracks/$trackId"),
          headers: headers,
        )
        .timeout(_timeout);
    _guard(resp);
  }

  Future<void> reorderPlaylist(int playlistId, List<int> trackIds) async {
    final resp = await _client
        .put(
          _uri("/api/playlists/$playlistId/tracks"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({"track_ids": trackIds}),
        )
        .timeout(_timeout);
    _guard(resp);
  }

  // ---------------------------------------------------------------- urls

  String streamUrl(int trackId) => "$base/api/stream/$trackId";
  String downloadUrl(int trackId) => "$base/api/download/$trackId";
  Uri coverUri(int albumId) => Uri.parse("$base/api/cover/$albumId");

  /// Token-bearing URLs are used by media players (just_audio, system
  /// notifications, <img>) that cannot supply our Authorization header.
  String streamUrlWithToken(int trackId) {
    final url = streamUrl(trackId);
    final t = token;
    if (t == null || t.isEmpty) return url;
    return '$url?token=${Uri.encodeComponent(t)}';
  }

  Uri coverUriWithToken(int albumId) {
    final uri = coverUri(albumId);
    final t = token;
    if (t == null || t.isEmpty) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'token': t},
    );
  }

  // ---------------------------------------------------------------- helpers

  final http.Client _client = http.Client();

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw ServerException("Unexpected response from server");
    }
  }

  void _guard(http.Response resp) {
    if (resp.statusCode == 401) {
      onUnauthorized?.call();
      throw AuthException("Session expired");
    }
    if (resp.statusCode != 200) {
      throw ServerException("Server error (${resp.statusCode})");
    }
  }
}

/// Result of a conditional `/api/library` request.
class LibraryFetchResult {
  const LibraryFetchResult({
    this.data,
    this.etag,
    this.notModified = false,
  });

  final Map<String, dynamic>? data;
  final String? etag;
  final bool notModified;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ServerException implements Exception {
  ServerException(this.message);
  final String message;
  @override
  String toString() => message;
}
