import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'player_service.dart';
import 'ui/connect_screen.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: "com.salty.musiclab.audio",
      androidNotificationChannelName: "Music Lab",
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (_) {
    // Web (and some desktop targets) have no media-notification service;
    // playback still works fine.
  }

  final app = AppState();
  await app.loadSaved();

  final player = PlayerService(app)..init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<PlayerService>.value(value: player),
      ],
      child: const MusicLabApp(),
    ),
  );
}

class MusicLabApp extends StatelessWidget {
  const MusicLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Music Lab",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Consumer<AppState>(
        builder: (context, app, _) =>
            app.loggedIn ? const HomeShell() : const ConnectScreen(),
      ),
    );
  }
}
