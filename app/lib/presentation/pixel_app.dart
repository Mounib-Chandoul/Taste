import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import 'app_router.dart';
import 'providers/app_providers.dart';

class PixelApp extends ConsumerWidget {
  const PixelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final router = appRouter;
    return MaterialApp.router(
      title: 'Music Lab — Pixel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(accent: accent),
      routerConfig: router,
    );
  }
}
