/// Form validators.
///
/// These exist to give fast, kind feedback in the UI. They are not a security
/// boundary: every rule that matters is enforced again by a database constraint
/// or an Edge Function, because anything running on the user's device can be
/// bypassed.
abstract final class Validators {
  static final _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$",
  );

  /// Malaysian mobile numbers: `01X-XXXXXXX`, with or without the `+60`
  /// country code. Landlines are not accepted - a technician needs to be able
  /// to reach the customer on site.
  static final _malaysianMobilePattern = RegExp(r'^(?:\+?60|0)1\d{8,9}$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email address is required';
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Minimum eight characters with at least one letter and one digit.
  ///
  /// Deliberately not a maze of symbol classes: length and a mixed alphabet buy
  /// most of the strength, and rules people cannot satisfy push them towards
  /// reusing a password they already have.
  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) {
      return 'Use at least 8 characters';
    }
    if (!password.contains(RegExp('[A-Za-z]')) ||
        !password.contains(RegExp('[0-9]'))) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? fullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Full name is required';
    if (trimmed.length < 2) return 'Enter your full name';
    if (trimmed.length > 80) return 'That name is too long';
    return null;
  }

  /// Optional at sign-up, required before a service request is placed - a
  /// technician who cannot find the door needs a number to call.
  static String? phone(String? value, {bool isRequired = false}) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }
    if (!_malaysianMobilePattern.hasMatch(digits)) {
      return 'Enter a valid Malaysian mobile number, e.g. 012 345 6789';
    }
    return null;
  }

  /// Normalises any accepted phone format to E.164 for storage.
  ///
  /// `012 345 6789` and `+60123456789` are the same number and must not become
  /// two different rows.
  static String? normalisePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+60')) return digits;
    if (digits.startsWith('60')) return '+$digits';
    if (digits.startsWith('0')) return '+60${digits.substring(1)}';
    return digits;
  }

  /// Free-text problem description. The floor exists because "broken" gives a
  /// technician nothing to prepare with.
  static String? problemDescription(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Tell us what is wrong';
    if (trimmed.length < 10) {
      return 'Add a little more detail so we can match the right technician';
    }
    if (trimmed.length > 2000) return 'Please shorten your description';
    return null;
  }
}
