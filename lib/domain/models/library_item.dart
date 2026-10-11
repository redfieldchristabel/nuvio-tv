import 'content_type.dart';
import 'meta.dart';

/// A saved or watched library entry with its display preview.
class LibraryItem {
  const LibraryItem({
    required this.contentId,
    required this.contentType,
    required this.addedAt,
    this.preview,
    this.progressFraction,
  });

  final String contentId;
  final ContentType contentType;
  final DateTime addedAt;
  final MetaPreview? preview;
  final double? progressFraction;

  /// Display preview; falls back to a minimal placeholder.
  MetaPreview get previewOrDefault =>
      preview ?? MetaPreview(id: contentId, type: contentType);

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'contentType': contentType.wireName,
        'addedAt': addedAt.toIso8601String(),
        if (preview != null) 'preview': preview!.toJson(),
      };

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      contentId: (json['contentId'] as String?) ?? '',
      contentType: ContentType.fromString(json['contentType'] as String?),
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      preview: json['preview'] == null
          ? null
          : MetaPreview.fromJson(json['preview'] as Map<String, dynamic>),
    );
  }
}
