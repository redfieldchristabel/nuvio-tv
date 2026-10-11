import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Placeholder screens for the remaining tabs.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Placeholder(title: 'Search', hint: 'Addon search lands here');
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Placeholder(
        title: 'Library', hint: 'Saved items + continue watching land here');
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Placeholder(
        title: 'Settings', hint: 'Addons, playback, tracking land here');
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: NuvioColors.text)),
          const SizedBox(height: 8),
          Text(hint,
              style: const TextStyle(
                  color: NuvioColors.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}
