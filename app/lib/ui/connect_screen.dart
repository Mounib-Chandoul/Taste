import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../api.dart';
import 'theme.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.serverUrl != null) {
      _server.text = app.serverUrl!;
    } else if (kIsWeb) {
      // When the UI is served by the Music Lab server itself, the API lives
      // at the same origin - so connecting is just entering credentials.
      final origin = Uri.base.origin;
      if (origin.startsWith("http")) _server.text = origin;
    }
    if (app.username != null) _user.text = app.username!;
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.read<AppState>();
    try {
      await app.connect(
        serverUrl: _server.text,
        username: _user.text.trim(),
        password: _pass.text,
      );
      // AppState.loggedIn flips -> HomeShell replaces this screen
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } on ServerException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error =
          "Could not reach the server. Check the address, that the PC is "
          "running the server, and that both devices are on the same network.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Palette.line),
                        color: Palette.surfaceAlt,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.library_music,
                        size: 36,
                        color: Palette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Music Lab",
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(letterSpacing: -0.5),
                      ),
                      const _Caret(),
                    ],
                  ),
                  Text(
                    "your music, from your PC",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                    style: mono(context, color: Palette.fg),
                    decoration: const InputDecoration(
                      labelText: "Server address",
                      hintText: "http://192.168.1.10:4533",
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _user,
                    style: mono(context, color: Palette.fg),
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    onSubmitted: (_) => _connect(),
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _busy ? null : _connect,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(_busy ? "Connecting..." : "Connect"),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "music-lab v0.2 · self-hosted streaming",
                    textAlign: TextAlign.center,
                    style: mono(context, size: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A blinking terminal caret that trails the app title. Pure decoration;
/// the blink is an async pulse, cheaper than an animation controller.
class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _blink();
  }

  Future<void> _blink() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _visible = !_visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 26,
      margin: const EdgeInsets.only(left: 4, top: 6),
      color: _visible ? Palette.teal : Colors.transparent,
    );
  }
}
