import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'presentation/pixel_app.dart';

/// Entry point for the "Rice Desktop / Tokyo Night Pixel" front end.
///
/// This is now the default app (see [lib/main.dart]). It uses Riverpod,
/// go_router, the custom design system, and a repository/service layer that
/// can switch between mock data and the real Music Lab backend.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background audio notification/control on Android. Web/desktop have no
  // media notification service, so failures here are safe to ignore.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: "com.salty.musiclab.audio",
      androidNotificationChannelName: "Music Lab",
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (_) {}

  runApp(const ProviderScope(child: PixelApp()));
}
