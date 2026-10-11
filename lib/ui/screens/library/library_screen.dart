import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/models/library_item.dart';
import '../../../state/library_controller.dart';
import '../../components/poster_card.dart';

/// Library: saved items, watched, collections — D-pad grid.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibraryTab _tab = _LibraryTab.saved;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                NuvioSpacing.safeGutter, 24, NuvioSpacing.safeGutter, 8),
            child: Row(
              children: _LibraryTab.values.map((tab) {
                final selected = tab == _tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.enter)) {
                        setState(() => _tab = tab);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = tab),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? NuvioColors.text
                              : NuvioColors.card,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            color: selected
                                ? NuvioColors.bg
                                : NuvioColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Content
          Expanded(
            child: state.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: NuvioColors.accent),
              ),
              error: (e, _) => Center(
                child: Text('Could not load library',
                    style:
                        TextStyle(color: NuvioColors.textSecondary)),
              ),
              data: (data) {
                final items = switch (_tab) {
                  _LibraryTab.saved => data.saved,
                  _LibraryTab.watched => data.watched,
                  _LibraryTab.collections => const <LibraryItem>[],
                };
                if (items.isEmpty) {
                  return _EmptyLibrary(tab: _tab);
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      NuvioSpacing.safeGutter, 8,
                      NuvioSpacing.safeGutter, 40),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio:
                        NuvioSpacing.posterWidth / NuvioSpacing.posterHeight,
                    crossAxisSpacing: NuvioSpacing.cardGap,
                    mainAxisSpacing: NuvioSpacing.cardGap,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return PosterCard(
                      item: item.previewOrDefault,
                      progressFraction: item.progressFraction,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _LibraryTab {
  saved('Saved'),
  watched('Watched'),
  collections('Collections');

  const _LibraryTab(this.label);
  final String label;
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.tab});

  final _LibraryTab tab;

  @override
  Widget build(BuildContext context) {
    final message = switch (tab) {
      _LibraryTab.saved =>
        'Save titles from their detail page and they will show up here.',
      _LibraryTab.watched => 'Titles you finish will appear here.',
      _LibraryTab.collections => 'Create collections to organize your media.',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library_outlined,
              color: NuvioColors.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text(
            'Nothing here yet',
            style: TextStyle(
                color: NuvioColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: NuvioColors.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
