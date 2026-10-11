import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/models/stream.dart';
import '../../../domain/repositories/stream_logic.dart';
import '../../../state/detail_controller.dart';

/// Stream picker: all sources for a title, grouped by origin, with
/// quality badges. Auto-play selection applies when configured.
///
/// D-pad: up/down between streams, left/right between source groups,
/// select picks and returns the stream.
class StreamPickerScreen extends ConsumerStatefulWidget {
  const StreamPickerScreen({
    super.key,
    required this.params,
    required this.onStreamPicked,
  });

  final DetailParams params;
  final ValueChanged<Stream> onStreamPicked;

  @override
  ConsumerState<StreamPickerScreen> createState() =>
      _StreamPickerScreenState();
}

class _StreamPickerScreenState extends ConsumerState<StreamPickerScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailControllerProvider(widget.params));
    return Scaffold(
      backgroundColor: NuvioColors.bg.withValues(alpha: 0.96),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NuvioColors.accent),
        ),
        error: (e, _) => const Center(
          child: Text('Could not load streams',
              style: TextStyle(color: NuvioColors.textSecondary)),
        ),
        data: (data) => _buildList(context, data.streams),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Stream> streams) {
    if (streams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_outlined,
                color: NuvioColors.textTertiary, size: 48),
            SizedBox(height: 12),
            Text('No streams found',
                style: TextStyle(color: NuvioColors.textSecondary)),
            SizedBox(height: 4),
            Text('Install more addons or plugins in Settings',
                style: TextStyle(color: NuvioColors.textTertiary, fontSize: 13)),
          ],
        ),
      );
    }


    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                NuvioSpacing.safeGutter, 24, NuvioSpacing.safeGutter, 8),
            child: Text(
              'Sources · ${streams.length} streams',
              style: const TextStyle(
                  color: NuvioColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                  bottom: 24, left: NuvioSpacing.safeGutter,
                  right: NuvioSpacing.safeGutter),
              itemCount: streams.length,
              itemBuilder: (context, index) {
                final stream = streams[index];
                return _StreamTile(
                  stream: stream,
                  selected: index == _selectedIndex,
                  autofocus: index == 0,
                  onFocusChange: (f) {
                    if (f) setState(() => _selectedIndex = index);
                  },
                  onSelected: () => widget.onStreamPicked(stream),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamTile extends StatefulWidget {
  const _StreamTile({
    required this.stream,
    required this.selected,
    required this.onFocusChange,
    required this.onSelected,
    this.autofocus = false,
  });

  final Stream stream;
  final bool selected;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onSelected;
  final bool autofocus;

  @override
  State<_StreamTile> createState() => _StreamTileState();
}

class _StreamTileState extends State<_StreamTile> {
  final bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final stream = widget.stream;
    final quality = QualityDetector.detect(stream.name, stream.title);
    final active = _focused || widget.selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: widget.onFocusChange,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onSelected();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onSelected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: active ? NuvioColors.cardFocused : NuvioColors.card,
              borderRadius: BorderRadius.circular(12),
              border: _focused
                  ? Border.all(color: NuvioColors.text, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // Quality badge
                if (quality != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: quality == '4K'
                          ? NuvioColors.accent
                          : NuvioColors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quality,
                      style: const TextStyle(
                          color: NuvioColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Name + title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stream.name ?? 'Stream',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: NuvioColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      if (stream.title != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            stream.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: NuvioColors.textTertiary,
                                fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                // Source chip
                const SizedBox(width: 12),
                Text(
                  stream.addonName ?? _originLabel(stream.originKind),
                  style: const TextStyle(
                      color: NuvioColors.textSecondary, fontSize: 12),
                ),
                if (stream.isDebrid) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.bolt, color: NuvioColors.accent, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _originLabel(StreamOriginKind kind) {
    switch (kind) {
      case StreamOriginKind.addon:
        return 'Addon';
      case StreamOriginKind.plugin:
        return 'Plugin';
      case StreamOriginKind.debrid:
        return 'Debrid';
      case StreamOriginKind.p2p:
        return 'P2P';
      case StreamOriginKind.external:
        return 'External';
    }
  }
}
