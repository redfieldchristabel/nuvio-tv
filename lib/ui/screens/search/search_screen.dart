import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/models/meta.dart';
import '../../components/poster_card.dart';

/// Search: on-screen keyboard (D-pad), history chips, addon search.
///
/// The keyboard is a grid navigable by D-pad; results stream in debounced.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.onSearch});

  /// Hook for addon search integration (injected; tests override).
  final Future<List<MetaPreview>> Function(String query)? onSearch;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';
  List<MetaPreview> _results = [];
  List<String> _history = [];
  bool _searching = false;
  Timer? _debounce;
  LocalStore? _store;

  // Keyboard rows (QWERTY-ish, TV-optimized).
  static const _rows = [
    ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'],
    ['K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T'],
    ['U', 'V', 'W', 'X', 'Y', 'Z', '0', '1', '2', '3'],
    ['4', '5', '6', '7', '8', '9', '⌫', '␣', 'CLR', 'GO'],
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    _store ??= await LocalStore.create();
    setState(() {
      _history = _store!.getStringList(StorageKeys.searchHistory) ?? [];
    });
  }

  void _appendChar(String c) {
    setState(() => _query += c);
    _scheduleSearch();
  }

  void _backspace() {
    if (_query.isEmpty) return;
    setState(() => _query = _query.substring(0, _query.length - 1));
    _scheduleSearch();
  }

  void _clear() {
    setState(() {
      _query = '';
      _results = [];
    });
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    if (_query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _doSearch);
  }

  Future<void> _doSearch() async {
    final query = _query.trim();
    if (query.length < 2) return;
    setState(() => _searching = true);
    try {
      final results = widget.onSearch != null
          ? await widget.onSearch!(query)
          : const <MetaPreview>[];
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
      _rememberHistory(query);
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _rememberHistory(String query) async {
    _store ??= await LocalStore.create();
    final updated = <String>{query, ..._history}.take(10).toList();
    await _store!.setStringList(StorageKeys.searchHistory, updated);
    setState(() => _history = updated);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Query display
          Padding(
            padding: const EdgeInsets.fromLTRB(
                NuvioSpacing.safeGutter, 24, NuvioSpacing.safeGutter, 8),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: NuvioColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NuvioColors.border),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                _query.isEmpty ? 'Search…' : _query,
                style: TextStyle(
                  color: _query.isEmpty
                      ? NuvioColors.textTertiary
                      : NuvioColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // History chips
          if (_history.isNotEmpty && _query.isEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  left: NuvioSpacing.safeGutter, bottom: 8),
              child: Wrap(
                spacing: 8,
                children: _history
                    .take(6)
                    .map((h) => Chip(
                          label: Text(h,
                              style: const TextStyle(
                                  color: NuvioColors.textSecondary,
                                  fontSize: 13)),
                          backgroundColor: NuvioColors.card,
                          side:
                              const BorderSide(color: NuvioColors.border),
                        ))
                    .toList(),
              ),
            ),
          // Results or keyboard
          Expanded(
            child: _results.isNotEmpty ? _resultsGrid() : _keyboard(),
          ),
        ],
      ),
    );
  }

  Widget _keyboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: NuvioSpacing.safeGutter, vertical: 8),
      child: Column(
        children: _rows
            .map((row) => Expanded(
                  child: Row(
                    children: row
                        .map((key) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: _KeyButton(
                                  label: key,
                                  onPressed: () => _onKey(key),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _onKey(String key) {
    switch (key) {
      case '⌫':
        _backspace();
      case 'CLR':
        _clear();
      case 'GO':
        _doSearch();
      case '␣':
        _appendChar(' ');
      default:
        _appendChar(key);
    }
  }

  Widget _resultsGrid() {
    if (_searching) {
      return const Center(
          child: CircularProgressIndicator(color: NuvioColors.accent));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(NuvioSpacing.safeGutter, 8,
          NuvioSpacing.safeGutter, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio:
            NuvioSpacing.posterWidth / NuvioSpacing.posterHeight,
        crossAxisSpacing: NuvioSpacing.cardGap,
        mainAxisSpacing: NuvioSpacing.cardGap,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) => PosterCard(item: _results[index]),
    );
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
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
