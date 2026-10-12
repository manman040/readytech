import 'package:readytech/core/constants/db.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin transport layer over Supabase Auth and the `profiles` table.
///
/// Data sources speak the backend's language and are allowed to throw. The
/// repository above translates. Keeping the split means the Supabase SDK is
/// referenced in exactly one layer, which is what makes it replaceable.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Creates the account.
  ///
  /// `full_name`, `phone` and `role` travel in user metadata so the
  /// `handle_new_user` trigger can populate `profiles`, `user_roles` and - for
  /// a technician - `technician_profiles` in the same transaction as the insert
  /// into `auth.users`. That avoids a window where an account exists with no
  /// profile row. The trigger honours only `technician` from metadata; every
  /// other value, including `admin`, becomes a customer.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role.wireName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Exchanges the refresh token for a new access token.
  ///
  /// This is how the app learns that an email address was confirmed in a
  /// browser: the confirmation happened outside the app, so the only way to see
  /// it is to ask the backend for a fresh token.
  Future<AuthResponse> refreshSession() => _auth.refreshSession();

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.resetPasswordForEmail(email);

  Future<void> resendVerificationEmail(String email) =>
      _auth.resend(type: OtpType.signup, email: email);

  /// Loads the profile for the signed-in user.
  ///
  /// The `role` is read from `user_roles` through a view join rather than from
  /// the client's own claim, so a tampered local cache cannot promote anyone.
  Future<Profile> fetchProfile(String userId) async {
    final row = await _client
        .from(DbTable.profiles)
        .select(
          'id, full_name, email, phone, avatar_url, created_at, '
          'updated_at, ${DbTable.userRolesEmbed}(role)',
        )
        .eq('id', userId)
        .single();

    return Profile.fromJson(_flattenRole(row));
  }

  Future<Profile> updateProfile(
    String userId,
    Map<String, dynamic> values,
  ) async {
    final row = await _client
        .from(DbTable.profiles)
        .update(values)
        .eq('id', userId)
        .select(
          'id, full_name, email, phone, avatar_url, created_at, '
          'updated_at, ${DbTable.userRolesEmbed}(role)',
        )
        .single();

    return Profile.fromJson(_flattenRole(row));
  }

  /// PostgREST returns an embedded resource as a nested object or list;
  /// [Profile] wants a flat `role` key.
  Map<String, dynamic> _flattenRole(Map<String, dynamic> row) {
    final embedded = row[DbTable.userRoles];
    final roleValue = switch (embedded) {
      final Map<String, dynamic> map => map['role'],
      final List<dynamic> list when list.isNotEmpty =>
        (list.first as Map<String, dynamic>)['role'],
      _ => null,
    };

    return {...row, 'role': roleValue};
  }
}
