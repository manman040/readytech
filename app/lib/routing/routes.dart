/// Every route in the application.
///
/// Paths and names are declared once here so navigation is never a string
/// literal at a call site. A renamed route then breaks at compile time rather
/// than at runtime in a flow nobody re-tested.
abstract final class AppRoute {
  static const splash = _Route('splash', '/');
  static const signIn = _Route('sign-in', '/sign-in');
  static const signUp = _Route('sign-up', '/sign-up');
  static const forgotPassword = _Route('forgot-password', '/forgot-password');
  static const verifyEmail = _Route('verify-email', '/verify-email');

  /// Shown when the session is valid but the profile could not be loaded.
  static const sessionError = _Route('session-error', '/session-error');

  // Role landings. Each role's feature area is grafted onto these in the phases
  // that build them out.
  static const customerHome = _Route('customer-home', '/home');
  static const technicianHome = _Route('technician-home', '/technician');
  static const adminHome = _Route('admin-home', '/admin');

  /// Routes reachable without a session.
  static const Set<String> publicPaths = {
    '/sign-in',
    '/sign-up',
    '/forgot-password',
  };
}

class _Route {
  const _Route(this.name, this.path);

  final String name;
  final String path;

  @override
  String toString() => path;
}
