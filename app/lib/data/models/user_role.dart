/// The three roles ReadyTech is built around.
///
/// A role is never granted by the client. It is stored in `user_roles`, which
/// only an administrator (or the sign-up trigger) may write, and it is read
/// back into the JWT so that Row Level Security can act on it. The value held
/// in the app is a cache for routing decisions - never a grant of access.
///
/// Sign-up may *ask* for a role - see [canSelfRegister] - but the backend
/// decides. A technician who registers themselves starts unverified and is
/// not offered work until an administrator approves them.
enum UserRole {
  customer('customer'),
  technician('technician'),
  admin('admin')
  ;

  const UserRole(this.wireName);

  final String wireName;

  static const UserRole fallback = UserRole.customer;

  static UserRole fromWire(String? value) {
    for (final role in UserRole.values) {
      if (role.wireName == value) return role;
    }
    return fallback;
  }

  bool get isCustomer => this == UserRole.customer;
  bool get isTechnician => this == UserRole.technician;
  bool get isAdmin => this == UserRole.admin;

  /// Whether the sign-up form may offer this role.
  ///
  /// Mirrors `handle_new_user()` on the backend, which honours only
  /// `technician` from sign-up metadata and treats everything else as a
  /// customer. An administrator is appointed, never self-declared.
  bool get canSelfRegister => this != UserRole.admin;

  String get label => switch (this) {
    customer => 'Customer',
    technician => 'Technician',
    admin => 'Administrator',
  };
}
