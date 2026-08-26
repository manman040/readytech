import 'package:equatable/equatable.dart';
import 'package:readytech/data/models/user_role.dart';

/// A user's public-facing identity.
///
/// Deliberately separate from the auth account. `auth.users` owns credentials,
/// email confirmation state and session material; `profiles` owns the
/// information other people in the marketplace are allowed to see. No secret,
/// token or payment identifier belongs in this table.
class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromWire(json['role'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Fields a user is allowed to change about themselves. `role` is absent by
  /// design - it is not a client-writable column.
  Map<String, dynamic> toUpdateJson() => {
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
  };

  /// Initials for the avatar placeholder, e.g. "Adam Rahman" -> "AR".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.take(1).toUpperCase();
    return (parts.first.take(1) + parts.last.take(1)).toUpperCase();
  }

  /// The first name, for greetings such as "Welcome back, Adam".
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  bool get hasCompletedProfile => fullName.trim().isNotEmpty && phone != null;

  Profile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    UserRole? role,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    fullName,
    email,
    phone,
    avatarUrl,
    role,
    createdAt,
    updatedAt,
  ];
}

extension on String {
  /// First [count] characters, safe for short or empty strings.
  String take(int count) => length <= count ? this : substring(0, count);
}
