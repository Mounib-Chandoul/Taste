import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../api.dart';
import '../../../core/core.dart';
import '../../providers/app_providers.dart';
import '../../providers/session_actions.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _signup = false;
  bool _loading = false;
  String? _error;

  final _serverFocus = FocusNode();

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _serverCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _serverFocus.dispose();
    super.dispose();
  }

  final _serverCtrl = TextEditingController();

  Future<void> _submit() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    final server = _serverCtrl.text.trim();
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'error: username and password required');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if (server.isNotEmpty) {
        // Real backend login (Music Lab server)
        final api = ServerApi(server);
        await api.login(user, pass);
        final library = await api.library();
        List<Map<String, dynamic>> playlists = const [];
        try {
          playlists = await api.playlists();
        } catch (_) {
          // playlists endpoint may be unavailable; continue with library
        }
        await saveSession(
          ref,
          api: api,
          username: user,
          library: library,
          playlists: playlists,
        );
      } else {
        // Mock/demo mode
        await Future<void>.delayed(const Duration(milliseconds: 500));
        ref.read(backendSessionProvider.notifier).state = null;
        await clearPersistedSession();
      }
      if (!mounted) return;
      ref.read(pixelUsernameProvider.notifier).state = user;
      ref.read(pixelAuthProvider.notifier).state = true;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _guest() {
    ref.read(pixelUsernameProvider.notifier).state = 'guest';
    ref.read(pixelAuthProvider.notifier).state = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mode = _signup ? 'signup' : 'login';
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('user@aesthetic ~ \$ auth --mode=$mode',
                        style: AppTypography.prompt(color: colors.green)),
                    const SizedBox(height: 8),
                    Text(
                      _signup
                          ? 'demo profile — no data leaves this device.'
                          : 'authenticate to stream your Music Lab library.',
                      style: AppTypography.caption(),
                    ),
                    const SizedBox(height: 16),
                    PixelCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: colors.cardElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: colors.accent, width: 3),
                                ),
                                child: Icon(PhosphorIconsFill.lockKey,
                                    color: colors.accent, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('MUSIC LAB ACCESS',
                                        style: AppTypography.label(
                                            color: colors.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text('terminal auth v1',
                                        style: AppTypography.caption(
                                            color: colors.purple)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _Field(
                            label: 'username',
                            hint: 'enter handle',
                            controller: _userCtrl,
                            focusNode: _userFocus,
                            icon: PhosphorIconsRegular.user,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _passFocus.requestFocus(),
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            label: 'password',
                            hint: '••••••••',
                            controller: _passCtrl,
                            focusNode: _passFocus,
                            icon: PhosphorIconsRegular.key,
                            obscure: true,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _serverFocus.requestFocus(),
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            label: 'server (optional)',
                            hint: '192.168.0.4:4533 or leave blank for demo',
                            controller: _serverCtrl,
                            focusNode: _serverFocus,
                            icon: PhosphorIconsRegular.hardDrives,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!,
                                style: AppTypography.caption(color: colors.red)),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: PixelButton.label(
                                  label: _loading
                                      ? '...'
                                      : (_signup ? 'SIGN UP' : 'LOGIN'),
                                  color: colors.cardElevated,
                                  borderColor: colors.accent,
                                  textColor: colors.accent,
                                  onTap: _loading ? null : _submit,
                                ),
                              ),
                              const SizedBox(width: 10),
                              PixelButton.icon(
                                icon: PhosphorIconsBold.arrowRight,
                                onTap: _loading ? null : _submit,
                                color: colors.accent,
                                borderColor: colors.border,
                                iconColor: colors.card,
                                size: 44,
                                iconSize: 20,
                                tooltip: 'Submit',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _loading
                                ? null
                                : () => setState(() {
                                      _signup = !_signup;
                                      _error = null;
                                    }),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _signup
                                    ? 'have an account? switch to login'
                                    : 'new here? create an account',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption(color: colors.cyan),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _loading ? null : _guest,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'continue as guest →',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption(
                                    color: colors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 220.ms).slideY(
                          begin: 0.06,
                          end: 0,
                          duration: 240.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 14),
                    PixelCard(
                      padding: const EdgeInsets.all(12),
                      shadowOffset: const Offset(3, 3),
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.info,
                              color: colors.yellow, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Leave server blank for demo mode (mock data). Enter your Music Lab server address to sign in and stream from your real library.',
                              style: AppTypography.caption(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.icon,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final bool obscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(color: colors.textSecondary)),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: focusNode,
          builder: (context, _) {
            final focused = focusNode.hasFocus;
            return Container(
              decoration: BoxDecoration(
                color: colors.cardElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused ? colors.accent : colors.border,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.hardShadow,
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Icon(icon,
                      size: 18,
                      color:
                          focused ? colors.accent : colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      obscureText: obscure,
                      textInputAction: textInputAction,
                      onSubmitted: onSubmitted,
                      style: AppTypography.mono(
                          size: 14, color: colors.textPrimary),
                      cursorColor: colors.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: hint,
                        hintStyle: AppTypography.mono(
                            size: 14, color: colors.textSecondary),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
