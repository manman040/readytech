import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/utils/money.dart';

void main() {
  group('Money', () {
    test('holds whole sen', () {
      expect(const Money.ringgit(125).sen, 12500);
      expect(const Money(9950).sen, 9950);
      expect(Money.zero.isZero, isTrue);
    });

    test('adds without the drift a double would introduce', () {
      // 0.10 has no exact binary representation. Adding it ten times as a
      // double gives 0.9999999999999999; as integer sen it is exactly 100.
      final total = Money.sum(List.generate(10, (_) => const Money(10)));
      expect(total.sen, 100);
      expect(total.format(), 'RM1.00');
    });

    test('supports arithmetic', () {
      expect((const Money(2000) + const Money(3500)).sen, 5500);
      expect((const Money(5500) - const Money(500)).sen, 5000);
      expect((const Money(1000) * 3).sen, 3000);
      expect((-const Money(1000)).sen, -1000);
    });

    test('compares', () {
      expect(const Money(2000) > const Money(1000), isTrue);
      expect(const Money(1000) < const Money(2000), isTrue);
      expect(const Money(1000) >= const Money(1000), isTrue);
      expect(const Money(1000) <= const Money(1000), isTrue);
      expect(
        ([
          const Money(300),
          const Money(100),
          const Money(200),
        ]..sort()).map((m) => m.sen),
        [100, 200, 300],
      );
    });

    group('percentage', () {
      test('computes a commission share', () {
        // 10% of RM95.00 is RM9.50.
        expect(const Money(9500).percentage(10).sen, 950);
      });

      test('rounds half away from zero rather than truncating', () {
        // 10% of 1 sen is 0.1 sen -> 0.
        expect(const Money(1).percentage(10).sen, 0);
        // 10% of 5 sen is 0.5 sen -> 1, not 0.
        expect(const Money(5).percentage(10).sen, 1);
        // 12.5% of 1234 sen is 154.25 -> 154.
        expect(const Money(1234).percentage(12.5).sen, 154);
      });

      test('keeps the sign on a negative amount', () {
        expect(const Money(-1000).percentage(10).sen, -100);
      });
    });

    group('tryParse', () {
      test('accepts the shapes a user actually types', () {
        expect(Money.tryParse('125')?.sen, 12500);
        expect(Money.tryParse('125.5')?.sen, 12550);
        expect(Money.tryParse('125.50')?.sen, 12550);
        expect(Money.tryParse('RM125.50')?.sen, 12550);
        expect(Money.tryParse('  89.05 ')?.sen, 8905);
        expect(Money.tryParse('0.99')?.sen, 99);
      });

      test('rejects what it cannot represent, rather than guessing', () {
        expect(Money.tryParse(''), isNull);
        expect(Money.tryParse('abc'), isNull);
        expect(Money.tryParse('1.2.3'), isNull);
        // Three decimal places is not a sen amount.
        expect(Money.tryParse('12.345'), isNull);
        expect(Money.tryParse('12.'), isNull);
      });

      test('handles a negative amount, used for refunds', () {
        expect(Money.tryParse('-25.50')?.sen, -2550);
      });
    });

    group('format', () {
      test('renders Malaysian Ringgit to two decimal places', () {
        expect(const Money(12550).format(), 'RM125.50');
        expect(Money.zero.format(), 'RM0.00');
        expect(const Money(5).format(), 'RM0.05');
      });

      test('renders a pre-diagnosis range', () {
        expect(
          Money.formatRange(const Money(6000), const Money(11000)),
          'RM60.00 - RM110.00',
        );
      });
    });

    test('is a value type', () {
      expect(const Money(100), const Money(100));
      expect(const Money(100), isNot(const Money(101)));
    });
  });
}
