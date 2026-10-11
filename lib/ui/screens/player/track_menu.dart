import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/player/player_controller.dart';
import 'package:video_player_avplay/video_player.dart' show AudioTrack, TextTrack;
import '../../../core/theme/theme.dart';

/// Audio + subtitle track picker overlay (D-pad navigable).
///
/// Lists tracks reported by the platform player (video_player_avplay) and
/// applies selection via setTrackSelection. Empty sections hide themselves.
class TrackMenu extends StatelessWidget {
  const TrackMenu({super.key, required this.controller, required this.onClose});

  final PlayerController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NuvioColors.bg.withValues(alpha: 0.94),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  NuvioSpacing.safeGutter, 24, NuvioSpacing.safeGutter, 8),
              child: Row(
                children: [
                  const Text(
                    'Audio & Subtitles',
                    style: TextStyle(
                        color: NuvioColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: NuvioColors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                    bottom: 40, left: NuvioSpacing.safeGutter,
                    right: NuvioSpacing.safeGutter),
                children: [
                  if (controller.audioTracks.isNotEmpty) ...[
                    const _SectionLabel('Audio'),
                    ...controller.audioTracks.map((track) => _TrackTile(
                          label: _audioLabel(track),
                          selected:
                              controller.selectedAudioTrackId == track.trackId,
                          onSelect: () => controller.selectAudioTrack(track),
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (controller.textTracks.isNotEmpty) ...[
                    const _SectionLabel('Subtitles'),
                    ...controller.textTracks.map((track) => _TrackTile(
                          label: _textLabel(track),
                          selected:
                              controller.selectedTextTrackId == track.trackId,
                          onSelect: () => controller.selectTextTrack(track),
                        )),
                  ],
                  if (controller.audioTracks.isEmpty &&
                      controller.textTracks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'No selectable tracks in this stream',
                          style: TextStyle(
                              color: NuvioColors.textSecondary, fontSize: 15),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _audioLabel(AudioTrack track) {
    final lang = track.language;
    return lang.isEmpty ? 'Audio' : _langName(lang);
  }

  String _textLabel(TextTrack track) {
    final lang = track.language;
    return lang.isEmpty ? 'Subtitle' : _langName(lang);
  }

  String _langName(String code) {
    const names = {
      'eng': 'English',
      'kor': 'Korean',
      'jpn': 'Japanese',
      'spa': 'Spanish',
      'fra': 'French',
      'deu': 'German',
      'zho': 'Chinese',
      'ara': 'Arabic',
      'hin': 'Hindi',
      'tam': 'Tamil',
      'mal': 'Malay',
      'ind': 'Indonesian',
      'por': 'Portuguese',
      'rus': 'Russian',
      'tha': 'Thai',
      'vie': 'Vietnamese',
    };
    return names[code.toLowerCase()] ?? code.toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: NuvioColors.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _TrackTile extends StatefulWidget {
  const _TrackTile({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final Future<bool> Function() onSelect;

  @override
  State<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<_TrackTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Focus(
        autofocus: widget.selected,
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onSelect();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onSelect,
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
                Expanded(
                  child: Text(widget.label,
                      style: const TextStyle(
                          color: NuvioColors.text, fontSize: 16)),
                ),
                if (widget.selected)
                  const Icon(Icons.check_circle,
                      color: NuvioColors.accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
