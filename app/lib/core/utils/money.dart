import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// A Malaysian Ringgit amount held as a whole number of sen.
///
/// Currency is never represented as a `double` anywhere in ReadyTech. Binary
/// floating point cannot represent 0.10 exactly, so repeated addition of prices
/// drifts, and a receipt that is one sen out is a support ticket. Every amount
/// crossing the wire is an integer count of the minor unit and the database
/// columns are `bigint`.
///
/// Authoritative arithmetic - quotation totals, platform commission, technician
/// earnings - happens server side (see docs/ARCHITECTURE.md). This type exists
/// so the client can render and estimate without reintroducing floating point.
class Money extends Equatable implements Comparable<Money> {
  const Money(this.sen);

  /// Builds an amount from whole ringgit.
  const Money.ringgit(int ringgit) : sen = ringgit * 100;

  /// Parses a user-entered string such as `"125"`, `"125.5"` or `"RM125.50"`.
  ///
  /// Returns `null` when the text is not a well formed amount, so callers can
  /// surface a validation message rather than silently treating it as zero.
  static Money? tryParse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;

    final parts = cleaned.split('.');
    if (parts.length > 2) return null;

    final whole = int.tryParse(parts.first);
    if (whole == null) return null;

    if (parts.length == 1) return Money(whole * 100);

    final fractionText = parts[1];
    if (fractionText.isEmpty || fractionText.length > 2) return null;
    final fraction = int.tryParse(fractionText.padRight(2, '0'));
    if (fraction == null || fraction < 0) return null;

    final magnitude = whole.abs() * 100 + fraction;
    return Money(cleaned.startsWith('-') ? -magnitude : magnitude);
  }

  static const zero = Money(0);

  /// The amount, in sen. 1 ringgit == 100 sen.
  final int sen;

  bool get isZero => sen == 0;
  bool get isPositive => sen > 0;
  bool get isNegative => sen < 0;

  Money operator +(Money other) => Money(sen + other.sen);
  Money operator -(Money other) => Money(sen - other.sen);
  Money operator *(int factor) => Money(sen * factor);
  Money operator -() => Money(-sen);

  bool operator >(Money other) => sen > other.sen;
  bool operator <(Money other) => sen < other.sen;
  bool operator >=(Money other) => sen >= other.sen;
  bool operator <=(Money other) => sen <= other.sen;

  /// Takes [percent] of this amount, rounding half away from zero.
  ///
  /// Used for display-only previews of platform commission. The value stored
  /// against a payment is always the one the backend computed.
  Money percentage(double percent) {
    final exact = sen * percent / 100;
    return Money(exact.abs().round() * (exact.isNegative ? -1 : 1));
  }

  /// Sums [amounts] without leaving integer space.
  static Money sum(Iterable<Money> amounts) =>
      amounts.fold(zero, (total, amount) => total + amount);

  /// `RM125.50`
  String format() => _formatter.format(sen / 100);

  /// `RM125.50 - RM180.00`, used for pre-diagnosis estimates where an exact
  /// figure would be a promise ReadyTech cannot keep.
  static String formatRange(Money low, Money high) =>
      '${low.format()} - ${high.format()}';

  static final _formatter = NumberFormat.currency(
    locale: 'ms_MY',
    symbol: 'RM',
  );

  @override
  int compareTo(Money other) => sen.compareTo(other.sen);

  @override
  List<Object?> get props => [sen];

  @override
  String toString() => 'Money(${format()})';
}
