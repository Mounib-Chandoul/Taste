import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/models.dart';
import 'providers/app_providers.dart';
import 'screens/artist/artist_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/detail/collection_detail_screen.dart';
import 'screens/now_playing/now_playing_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'shell/app_shell.dart';

/// Single router instance so session helpers can navigate on 401/logout.
final appRouter = createAppRouter();

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/now-playing',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const NowPlayingScreen(),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return Consumer(
            builder: (context, ref, _) {
              final playlists =
                  ref.watch(playlistsProvider).asData?.value ?? const <Playlist>[];
              final playlist = playlists.firstWhere(
                (p) => p.id == id,
                orElse: () => Playlist(
                  id: id,
                  title: 'Playlist',
                  description: '',
                  coverUrl: '',
                  trackIds: const [],
                ),
              );
              return CollectionDetailScreen(
                args: CollectionDetailArgs.playlist(playlist),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/album',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? const {};
          return CollectionDetailScreen(
            args: CollectionDetailArgs.album(
              title: extra['title'] ?? 'Album',
              artist: extra['artist'] ?? 'Unknown',
              artUrl: extra['artUrl'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/artist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ArtistScreen(artistId: id);
        },
      ),
    ],
  );
}
