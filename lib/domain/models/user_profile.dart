/// A user profile (multi-profile support like the official clients).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.avatarColors = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final List<String> avatarColors;
  final DateTime? createdAt;

  String get initial => name.trim().isEmpty
      ? 'P'
      : name.trim().substring(0, 1).toUpperCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'avatarColors': avatarColors,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Profile',
      avatarUrl: json['avatarUrl'] as String?,
      avatarColors: ((json['avatarColors'] as List<dynamic>?) ?? const [])
          .map((c) => c.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// Home layout experience mode selected during onboarding.
enum ExperienceMode { modern, grid, classic }

extension ExperienceModeX on ExperienceMode {
  String get id {
    switch (this) {
      case ExperienceMode.modern:
        return 'modern';
      case ExperienceMode.grid:
        return 'grid';
      case ExperienceMode.classic:
        return 'classic';
    }
  }

  static ExperienceMode fromId(String? id) {
    switch (id) {
      case 'grid':
        return ExperienceMode.grid;
      case 'classic':
        return ExperienceMode.classic;
      default:
        return ExperienceMode.modern;
    }
  }
}
