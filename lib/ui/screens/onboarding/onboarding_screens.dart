import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../state/settings_controller.dart';
import '../../../domain/models/user_profile.dart';

/// Onboarding step 1: pick the home experience mode.
///
/// Port of the official ExperienceModeSelectionScreen: three modes
/// (Modern / Grid / Classic) shown as focusable cards.
class ExperienceModeSelectionScreen extends ConsumerStatefulWidget {
  const ExperienceModeSelectionScreen({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<ExperienceMode> onSelected;

  @override
  ConsumerState<ExperienceModeSelectionScreen> createState() =>
      _ExperienceModeSelectionScreenState();
}

class _ExperienceModeSelectionScreenState
    extends ConsumerState<ExperienceModeSelectionScreen> {
  ExperienceMode? _hovered;

  static const _modes = <(ExperienceMode, String, String, IconData)>[
    (
      ExperienceMode.modern,
      'Modern',
      'Hero backdrop with smooth rows',
      Icons.auto_awesome
    ),
    (
      ExperienceMode.grid,
      'Grid',
      'Dense poster grid, more at once',
      Icons.grid_view_outlined
    ),
    (
      ExperienceMode.classic,
      'Classic',
      'Simple list layout, lightest',
      Icons.view_list_outlined
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuvioColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Nuvio',
              style: TextStyle(
                  color: NuvioColors.text,
                  fontSize: 34,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how your home screen looks',
              style: TextStyle(color: NuvioColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _modes.map((mode) {
                final (id, title, subtitle, icon) = mode;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _ModeCard(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    selected: _hovered == id,
                    onTap: () {
                      setState(() => _hovered = id);
                      ref
                          .read(settingsProvider.notifier)
                          .modify((s) => s.copyWith(experienceMode: id));
                      widget.onSelected(id);
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.selected;
    return Focus(
      autofocus: widget.title == 'Modern',
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 240,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: active ? NuvioColors.cardFocused : NuvioColors.card,
            borderRadius: BorderRadius.circular(18),
            border: _focused
                ? Border.all(color: NuvioColors.text, width: 3)
                : Border.all(color: NuvioColors.border),
          ),
          child: Column(
            children: [
              Icon(widget.icon,
                  size: 44,
                  color: active ? NuvioColors.text : NuvioColors.textSecondary),
              const SizedBox(height: 14),
              Text(widget.title,
                  style: TextStyle(
                      color: NuvioColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(widget.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: NuvioColors.textTertiary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding step 2: install essential addons (Cinemeta preselected).
class EssentialAddonSetupScreen extends ConsumerStatefulWidget {
  const EssentialAddonSetupScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  ConsumerState<EssentialAddonSetupScreen> createState() =>
      _EssentialAddonSetupScreenState();
}

class _EssentialAddonSetupScreenState
    extends ConsumerState<EssentialAddonSetupScreen> {
  static const _suggested = <(String, String, String)>[
    (
      'https://v3-cinemeta.strem.io/manifest.json',
      'Cinemeta',
      'Official catalogs & metadata for movies and series'
    ),
    (
      'https://v3-cinemeta.strem.io/manifest.json',
      'Cinemeta Trailers',
      'Trailer streams from YouTube'
    ),
  ];

  final Set<int> _selected = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuvioColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Add your first sources',
              style: TextStyle(
                  color: NuvioColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'These addons provide catalogs and metadata. You can add more later.',
              style: TextStyle(color: NuvioColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 32),
            ..._suggested.asMap().entries.map((entry) {
              final index = entry.key;
              final (url, name, description) = entry.value;
              final checked = _selected.contains(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AddonToggle(
                  name: name,
                  description: description,
                  checked: checked,
                  onToggle: () => setState(() {
                    checked
                        ? _selected.remove(index)
                        : _selected.add(index);
                  }),
                ),
              );
            }),
            const SizedBox(height: 24),
            _FinishButton(
              label: 'Finish setup',
              onTap: widget.onFinished,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddonToggle extends StatefulWidget {
  const _AddonToggle({
    required this.name,
    required this.description,
    required this.checked,
    required this.onToggle,
  });

  final String name;
  final String description;
  final bool checked;
  final VoidCallback onToggle;

  @override
  State<_AddonToggle> createState() => _AddonToggleState();
}

class _AddonToggleState extends State<_AddonToggle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: false,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onToggle();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 560,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _focused ? NuvioColors.cardFocused : NuvioColors.card,
            borderRadius: BorderRadius.circular(14),
            border: _focused
                ? Border.all(color: NuvioColors.text, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.checked
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: widget.checked ? NuvioColors.accent : NuvioColors.textTertiary,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: const TextStyle(
                            color: NuvioColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    Text(widget.description,
                        style: const TextStyle(
                            color: NuvioColors.textTertiary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishButton extends StatefulWidget {
  const _FinishButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_FinishButton> createState() => _FinishButtonState();
}

class _FinishButtonState extends State<_FinishButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            color: _focused ? NuvioColors.text : NuvioColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(widget.label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
