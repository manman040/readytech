/// The three roles ReadyTech is built around.
///
/// A role is never chosen by the client. It is stored in `user_roles`, which
/// only an administrator (or the sign-up trigger, for the default role) may
/// write, and it is read back into the JWT so that Row Level Security can act
/// on it. The value held in the app is a cache for routing decisions - never a
/// grant of access.
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

  String get label => switch (this) {
    customer => 'Customer',
    technician => 'Technician',
    admin => 'Administrator',
  };
}
