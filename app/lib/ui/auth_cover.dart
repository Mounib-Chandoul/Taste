import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'theme.dart';

/// Album cover fetched from the server with the auth header attached.
class AuthCover extends StatelessWidget {
  const AuthCover({
    super.key,
    required this.albumId,
    this.fit = BoxFit.cover,
  });

  final int albumId;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.loggedIn) {
      return _placeholder(context);
    }
    // On web, <img> requests can't carry custom auth headers in a portable
    // way, so we pass the token as a query parameter (the server accepts it).
    final uri = kIsWeb
        ? app.api.coverUriWithToken(albumId)
        : app.api.coverUri(albumId);
    return Image.network(
      uri.toString(),
      headers: kIsWeb ? null : app.api.headers,
      fit: fit,
      // covers rarely change; keep memory cache default
      errorBuilder: (_, __, ___) => _placeholder(context),
      frameBuilder: (context, child, frame, wasSync) =>
          frame == null ? child : child,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(context, child: child),
    );
  }

  Widget _placeholder(BuildContext context, {Widget? child}) => Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Palette.surfaceAlt, Palette.surface],
          ),
        ),
        child: child ??
            Icon(Icons.album,
                size: 40,
                color: Palette.dim.withValues(alpha: 0.5)),
      );
}
