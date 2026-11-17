// A tiny ranked-search engine for the local library.
//
// Why not `String.contains`? Because "smart search" is about *ranking*:
// when you type "bohem", the exact-prefix match should beat a fuzzy
// subsequence buried mid-word. This module scores every candidate with
// tiered match quality, weights the fields (title > artist > album), ANDs
// multi-token queries, and sorts by total score.
//
// Everything runs on the cached library copy - no network round-trips,
// results are instant and work fully offline.

import 'models.dart';

/// One scored result. Generic so tracks/albums/artists share the plumbing.
class Hit<T> {
  Hit(this.item, this.score);
  final T item;
  final double score;
}

/// Match quality tiers, higher is better.
const double _tierExact = 100; // whole field equals the query
const double _tierPrefix = 80; // field starts with the query
const double _tierWord = 75; // a word inside the field starts with it
const double _tierSubstring = 60; // query appears mid-field
const double _tierSubsequence = 25; // fuzzy: letters appear in order

/// Field weights for a track. The song's own name matters most; matching
/// the album title alone is a weak signal.
const double _wTitle = 1.0;
const double _wArtist = 0.7;
const double _wAlbum = 0.5;
const double _wAlbumArtist = 0.6;

class SearchEngine {
  /// Normalizes text for matching: case-folded, accents stripped,
  /// whitespace collapsed. "Café Del Mar" -> "cafe del mar".
  static String fold(String s) {
    var out = s.toLowerCase();
    const accents = {
      "á": "a", "à": "a", "â": "a", "ä": "a", "ã": "a",
      "é": "e", "è": "e", "ê": "e", "ë": "e",
      "í": "i", "ì": "i", "î": "i", "ï": "i",
      "ó": "o", "ò": "o", "ô": "o", "ö": "o", "õ": "o",
      "ú": "u", "ù": "u", "û": "u", "ü": "u",
      "ñ": "n", "ç": "c", "ß": "ss",
    };
    out = out.replaceAllMapped(
      RegExp("[áàâäãéèêëíìîïóòôöõúùûüñçß]"),
      (m) => accents[m[0]] ?? m[0]!,
    );
    return out.replaceAll(RegExp(r"\s+"), " ").trim();
  }

  /// Splits a query into normalized tokens ("the beatles hey" -> 3 tokens).
  static List<String> tokenize(String query) =>
      fold(query).split(" ").where((t) => t.isNotEmpty).toList();

  /// Score of the best way [field] matches [token], or 0 for no match.
  static double _fieldScore(String field, String token) {
    if (token.isEmpty || field.isEmpty) return 0;
    if (field == token) return _tierExact;
    if (field.startsWith(token)) return _tierPrefix;
    if (field.contains(" $token")) return _tierWord;
    if (field.contains(token)) return _tierSubstring;
    if (isSubsequence(token, field)) return _tierSubsequence;
    return 0;
  }

  /// Is every character of [needle] present in [haystack] in order?
  /// "btran" ~ "beautiful trance". Classic greedy two-pointer scan: O(n).
  static bool isSubsequence(String needle, String haystack) {
    var i = 0;
    for (var j = 0; j < haystack.length && i < needle.length; j++) {
      if (haystack.codeUnitAt(j) == needle.codeUnitAt(i)) i++;
    }
    return i == needle.length;
  }

  /// AND-semantics across tokens: every token must match *somewhere* in at
  /// least one field. Document score = sum of per-token best field scores.
  static double _docScore(List<String> tokens, Map<String, double> fields) {
    var total = 0.0;
    for (final token in tokens) {
      var best = 0.0;
      fields.forEach((field, weight) {
        final tier = _fieldScore(field, token);
        if (tier > 0 && tier * weight > best) best = tier * weight;
      });
      if (best == 0) return 0; // one unmatched token kills the doc
      total += best;
    }
    return total;
  }

  static List<Hit<Track>> searchTracks(
    String query,
    List<Track> tracks, {
    required Album? Function(Track) albumOf,
  }) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const [];
    final out = <Hit<Track>>[];
    for (final t in tracks) {
      final album = albumOf(t);
      final score = _docScore(tokens, {
        fold(t.title): _wTitle,
        fold(t.artist): _wArtist,
        fold(album?.name ?? ""): _wAlbum,
        fold(album?.artist ?? t.artist): _wAlbumArtist,
      });
      if (score > 0) out.add(Hit(t, score));
    }
    return out..sort(_compareDesc);
  }

  static List<Hit<Album>> searchAlbums(String query, List<Album> albums) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const [];
    final out = <Hit<Album>>[];
    for (final a in albums) {
      final score = _docScore(tokens, {
        fold(a.name): 1.0,
        fold(a.artist): 0.7,
      });
      if (score > 0) out.add(Hit(a, score));
    }
    return out..sort(_compareDesc);
  }

  static List<Hit<Artist>> searchArtists(String query, List<Artist> artists) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const [];
    final out = <Hit<Artist>>[];
    for (final a in artists) {
      final score = _docScore(tokens, {fold(a.name): 1.0});
      if (score > 0) out.add(Hit(a, score));
    }
    return out..sort(_compareDesc);
  }
}

int _compareDesc<T>(Hit<T> a, Hit<T> b) => b.score.compareTo(a.score);
