/// A catalog row shown on the home screen or discover page.
///
/// Combines the addon that serves it with the resolved preview items.
class CatalogRow {
  const CatalogRow({
    required this.addonId,
    required this.addonName,
    required this.type,
    required this.catalogId,
    required this.catalogName,
    this.genre,
    this.items = const [],
    this.addonOrderIndex = 0,
    this.isLoading = false,
  });

  final String addonId;
  final String addonName;
  final String type;
  final String catalogId;
  final String catalogName;
  final String? genre;
  final List<dynamic> items;
  final int addonOrderIndex;
  final bool isLoading;

  String get rowKey => '$addonId|$type|$catalogId|${genre ?? ''}';

  CatalogRow copyWith({
    String? addonId,
    String? addonName,
    String? type,
    String? catalogId,
    String? catalogName,
    String? genre,
    List<dynamic>? items,
    int? addonOrderIndex,
    bool? isLoading,
  }) {
    return CatalogRow(
      addonId: addonId ?? this.addonId,
      addonName: addonName ?? this.addonName,
      type: type ?? this.type,
      catalogId: catalogId ?? this.catalogId,
      catalogName: catalogName ?? this.catalogName,
      genre: genre ?? this.genre,
      items: items ?? this.items,
      addonOrderIndex: addonOrderIndex ?? this.addonOrderIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
