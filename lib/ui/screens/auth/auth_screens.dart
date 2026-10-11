import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../data/remote/nuvio_backend_client.dart';
import '../../../state/auth_controller.dart';

/// QR sign-in: shows the pairing URL + user code, polls until approved.
///
/// Flow (matches official AuthQrSignInScreen):
/// 1. On mount: start device login session -> show code + URL
/// 2. Poll every [interval] until approved/expired
/// 3. On success: exchange tokens -> session ready -> onAuthenticated
class AuthQrSignInScreen extends ConsumerStatefulWidget {
  const AuthQrSignInScreen({
    super.key,
    required this.onAuthenticated,
    this.onBack,
  });

  final ValueChanged<NuvioSession> onAuthenticated;
  final VoidCallback? onBack;

  @override
  ConsumerState<AuthQrSignInScreen> createState() =>
      _AuthQrSignInScreenState();
}

class _AuthQrSignInScreenState extends ConsumerState<AuthQrSignInScreen> {
  Timer? _pollTimer;
  bool _starting = true;
  bool _exchanging = false;
  String? _error;
  DeviceLoginSession? _session;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    final result = await ref.read(authControllerProvider.notifier).startPairing();
    if (!mounted) return;
    if (result.isErr) {
      setState(() {
        _starting = false;
        _error = result.errorOrNull!.userMessage;
      });
      return;
    }
    final session = result.valueOrNull!;
    setState(() {
      _starting = false;
      _session = session;
    });
    _schedulePoll(session);
  }

  void _schedulePoll(DeviceLoginSession session) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: session.pollIntervalSeconds),
      (_) => _poll(session),
    );
  }

  Future<void> _poll(DeviceLoginSession session) async {
    if (_exchanging) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .pollPairing(session);
    if (!mounted) return;
    final poll = result.valueOrNull;
    if (poll == null) return;
    if (poll.isPending) return;

    // Approved: exchange tokens.
    _pollTimer?.cancel();
    setState(() => _exchanging = true);
    final exchangeResult = await ref
        .read(authControllerProvider.notifier)
        .exchangePairing(session);
    if (!mounted) return;
    if (exchangeResult.isErr) {
      setState(() {
        _exchanging = false;
        _error = exchangeResult.errorOrNull!.userMessage;
      });
      return;
    }
    widget.onAuthenticated(exchangeResult.valueOrNull!);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuvioColors.bg,
      body: Center(
        child: _starting
            ? const CircularProgressIndicator(color: NuvioColors.accent)
            : _error != null
                ? _errorView()
                : _codeView(),
      ),
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline,
            color: NuvioColors.error, size: 48),
        const SizedBox(height: 12),
        Text(_error ?? 'Pairing failed',
            style:
                const TextStyle(color: NuvioColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 20),
        _ActionButton(label: 'Try again', onTap: _start),
      ],
    );
  }

  Widget _codeView() {
    final session = _session!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Sign in to Nuvio',
          style: TextStyle(
              color: NuvioColors.text,
              fontSize: 30,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'On your phone or computer, open:',
          style: TextStyle(color: NuvioColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: NuvioColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            session.loginUrl,
            style: const TextStyle(
                color: NuvioColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 28),
        const Text('Then enter this code:',
            style: TextStyle(color: NuvioColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
          decoration: BoxDecoration(
            color: NuvioColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NuvioColors.accent, width: 2),
          ),
          child: Text(
            session.userCode,
            style: const TextStyle(
                color: NuvioColors.text,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 6),
          ),
        ),
        const SizedBox(height: 28),
        if (_exchanging)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: NuvioColors.accent, strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Signing you in…',
                  style: TextStyle(color: NuvioColors.textSecondary)),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: NuvioColors.textTertiary, strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Waiting for approval…',
                  style:
                      const TextStyle(color: NuvioColors.textTertiary, fontSize: 14)),
            ],
          ),
        const SizedBox(height: 32),
        _ActionButton(label: 'Back', onTap: widget.onBack ?? () {}),
      ],
    );
  }
}

/// Manual sync-code entry (alternative to QR).
class SyncCodeScreen extends ConsumerStatefulWidget {
  const SyncCodeScreen({
    super.key,
    required this.onAuthenticated,
    this.onBack,
  });

  final ValueChanged<NuvioSession> onAuthenticated;
  final VoidCallback? onBack;

  @override
  ConsumerState<SyncCodeScreen> createState() => _SyncCodeScreenState();
}

class _SyncCodeScreenState extends ConsumerState<SyncCodeScreen> {
  String _code = '';
  bool _submitting = false;
  String? _error;

  void _append(String c) {
    if (_code.length >= 12) return;
    setState(() => _code += c);
  }

  void _backspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    if (_code.trim().length < 4 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .submitSyncCode(_code.trim());
    if (!mounted) return;
    if (result.isErr) {
      setState(() {
        _submitting = false;
        _error = result.errorOrNull!.userMessage;
      });
      return;
    }
    widget.onAuthenticated(result.valueOrNull!);
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3', '4', '5', '6'],
      ['7', '8', '9', '0', 'A', 'B'],
      ['C', 'D', 'E', 'F', 'G', 'H'],
      ['I', 'J', 'K', 'L', 'M', 'N'],
      ['O', 'P', 'Q', 'R', 'S', 'T'],
      ['U', 'V', 'W', 'X', 'Y', 'Z'],
      ['⌫', '␣', '-', 'OK'],
    ];
    return Scaffold(
      backgroundColor: NuvioColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter sync code',
              style: TextStyle(
                  color: NuvioColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Type the code from your Nuvio account page',
              style: TextStyle(color: NuvioColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              width: 320,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: NuvioColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NuvioColors.accent, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                _code.isEmpty ? '····' : _code,
                style: const TextStyle(
                    color: NuvioColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style:
                      const TextStyle(color: NuvioColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            if (_submitting)
              const CircularProgressIndicator(color: NuvioColors.accent)
            else
              ...rows.map((row) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: row
                        .map((key) => Padding(
                              padding: const EdgeInsets.all(4),
                              child: _KeyboardKey(
                                label: key,
                                onTap: () {
                                  switch (key) {
                                    case '⌫':
                                      _backspace();
                                    case 'OK':
                                      _submit();
                                    case '␣':
                                      _append(' ');
                                    default:
                                      _append(key);
                                  }
                                },
                              ),
                            ))
                        .toList(),
                  )),
            const SizedBox(height: 16),
            _ActionButton(label: 'Back', onTap: widget.onBack ?? () {}),
          ],
        ),
      ),
    );
  }
}

class _KeyboardKey extends StatefulWidget {
  const _KeyboardKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_KeyboardKey> createState() => _KeyboardKeyState();
}

class _KeyboardKeyState extends State<_KeyboardKey> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 64,
          height: 52,
          decoration: BoxDecoration(
            color: _focused ? NuvioColors.text : NuvioColors.card,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: _focused ? NuvioColors.bg : NuvioColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: NuvioSpacing.buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          decoration: BoxDecoration(
            color: _focused ? NuvioColors.text : NuvioColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
                color: _focused ? NuvioColors.bg : NuvioColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
