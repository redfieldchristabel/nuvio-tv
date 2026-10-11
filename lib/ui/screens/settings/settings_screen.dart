import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debrid/debrid_service.dart';
import '../../../core/theme/theme.dart';
import '../../../state/settings_controller.dart';

/// Settings screen: sections for playback, sources, integrations, about.
///
/// D-pad: up/down between rows, select toggles/enters.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final debridAccounts = ref.watch(debridAccountsProvider).valueOrNull ?? {};

    return Scaffold(
      body: settings == null
          ? const Center(
              child: CircularProgressIndicator(color: NuvioColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  NuvioSpacing.safeGutter, 24, NuvioSpacing.safeGutter, 40),
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                      color: NuvioColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),

                // ---- Playback ----
                _sectionHeader('Playback'),
                _choiceRow<int>(
                  label: 'Skip interval',
                  value: settings.skipIntervalSeconds,
                  options: const [5, 10, 15, 30, 60],
                  format: (v) => '${v}s',
                  onPick: (v) => ref
                      .read(settingsProvider.notifier)
                      .modify((s) => s.copyWith(skipIntervalSeconds: v)),
                ),
                _toggleRow(
                  label: 'Auto-play next episode',
                  value: settings.autoPlayNext,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .modify((s) => s.copyWith(autoPlayNext: v)),
                ),
                _choiceRow<String>(
                  label: 'Auto-play stream',
                  value: settings.autoPlayMode,
                  options: const [
                    StreamAutoPlayMode.manual,
                    StreamAutoPlayMode.firstStream,
                    StreamAutoPlayMode.regexMatch,
                  ],
                  format: (v) => switch (v) {
                    StreamAutoPlayMode.firstStream => 'First stream',
                    StreamAutoPlayMode.regexMatch => 'Regex match',
                    _ => 'Manual',
                  },
                  onPick: (v) => ref
                      .read(settingsProvider.notifier)
                      .modify((s) => s.copyWith(autoPlayMode: v)),
                ),

                // ---- P2P ----
                _sectionHeader('Torrents (P2P)'),
                _toggleRow(
                  label: 'Enable P2P streaming',
                  value: settings.p2pEnabled,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .modify((s) => s.copyWith(p2pEnabled: v)),
                ),
                _toggleRow(
                  label: 'Allow uploading while streaming',
                  value: settings.enableUpload,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .modify((s) => s.copyWith(enableUpload: v)),
                ),

                // ---- Debrid ----
                _sectionHeader('Debrid'),
                ...DebridProvider.all.map((provider) {
                  final account = debridAccounts[provider.id];
                  return _debridRow(provider, account);
                }),

                // ---- Integrations ----
                _sectionHeader('Integrations'),
                _toggleRow(
                  label: 'Trakt',
                  value: settings.traktConnected,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .modify((s) => s.copyWith(traktConnected: v)),
                ),
                _toggleRow(
                  label: 'Simkl',
                  value: settings.simklConnected,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .modify((s) => s.copyWith(simklConnected: v)),
                ),

                // ---- About ----
                _sectionHeader('About'),
                const _StaticRow(
                    label: 'Nuvio for Tizen', value: 'Flutter 3.47.7'),
                const _StaticRow(label: 'Version', value: '1.0.0'),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            color: NuvioColors.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _toggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _FocusRow(
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: NuvioColors.accent,
      ),
      child: Text(label,
          style:
              const TextStyle(color: NuvioColors.text, fontSize: 16)),
    );
  }

  Widget _choiceRow<T>({
    required String label,
    required T value,
    required List<T> options,
    required String Function(T) format,
    required ValueChanged<T> onPick,
  }) {
    final currentIndex = options.indexOf(value);
    return _FocusRow(
      onTap: () {
        final next = (currentIndex + 1) % options.length;
        onPick(options[next]);
      },
      trailing: Text(
        format(value),
        style: const TextStyle(
            color: NuvioColors.accent,
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),
      child: Text(label,
          style:
              const TextStyle(color: NuvioColors.text, fontSize: 16)),
    );
  }

  Widget _debridRow(DebridProvider provider, DebridAccount? account) {
    return _FocusRow(
      onTap: () {
        if (account != null) {
          ref.read(debridAccountsProvider.notifier).disconnect(provider.id);
        }
        // Connect flow (device-code / API key entry) lands with the
        // full settings dialogs; for now disconnect works.
      },
      trailing: account != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Text(maskApiKey(account.apiKey),
                  style: const TextStyle(
                      color: NuvioColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle,
                  color: NuvioColors.accent, size: 20),
            ])
          : const Text('Connect',
              style: TextStyle(
                  color: NuvioColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
      child: Text(provider.displayName,
          style: const TextStyle(color: NuvioColors.text, fontSize: 16)),
    );
  }
}

class _FocusRow extends StatefulWidget {
  const _FocusRow({
    required this.onTap,
    required this.trailing,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget trailing;
  final Widget child;

  @override
  State<_FocusRow> createState() => _FocusRowState();
}

class _FocusRowState extends State<_FocusRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Focus(
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
            duration: const Duration(milliseconds: 140),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _focused ? NuvioColors.cardFocused : NuvioColors.card,
              borderRadius: BorderRadius.circular(12),
              border: _focused
                  ? Border.all(color: NuvioColors.text, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(child: widget.child),
                widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticRow extends StatelessWidget {
  const _StaticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: NuvioColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: NuvioColors.textSecondary, fontSize: 15)),
          ),
          Text(value,
              style: const TextStyle(
                  color: NuvioColors.textTertiary, fontSize: 14)),
        ],
      ),
    );
  }
}
