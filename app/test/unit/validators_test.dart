import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/helpers/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts ordinary addresses', () {
      expect(Validators.email('adam@readytech.test'), isNull);
      expect(Validators.email('adam.rahman+work@example.co.uk'), isNull);
      expect(Validators.email('  spaced@example.com  '), isNull);
    });

    test('rejects malformed addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('adam'), isNotNull);
      expect(Validators.email('adam@'), isNotNull);
      expect(Validators.email('adam@example'), isNotNull);
      expect(Validators.email('@example.com'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('accepts eight or more characters with a letter and a digit', () {
      expect(Validators.password('ReadyTech123'), isNull);
      expect(Validators.password('abcd1234'), isNull);
    });

    test('rejects passwords that are too short or too plain', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('abc123'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
    });

    test('matches confirmation', () {
      expect(Validators.confirmPassword('abcd1234', 'abcd1234'), isNull);
      expect(Validators.confirmPassword('abcd1234', 'abcd12345'), isNotNull);
      expect(Validators.confirmPassword('', 'abcd1234'), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('accepts Malaysian mobile numbers in the shapes people type', () {
      expect(Validators.phone('0123456789'), isNull);
      expect(Validators.phone('012-345 6789'), isNull);
      expect(Validators.phone('+60123456789'), isNull);
      expect(Validators.phone('60123456789'), isNull);
      // Ten-digit mobile prefixes such as 011.
      expect(Validators.phone('01123456789'), isNull);
    });

    test('is optional unless the caller says otherwise', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone(null), isNull);
      expect(Validators.phone('', isRequired: true), isNotNull);
    });

    test('rejects landlines and malformed numbers', () {
      // A technician needs a number they can reach on site.
      expect(Validators.phone('0312345678'), isNotNull);
      expect(Validators.phone('012345'), isNotNull);
      expect(Validators.phone('abcdefghij'), isNotNull);
    });
  });

  group('Validators.normalisePhone', () {
    test('collapses every accepted format to one E.164 value', () {
      const expected = '+60123456789';
      expect(Validators.normalisePhone('0123456789'), expected);
      expect(Validators.normalisePhone('012-345 6789'), expected);
      expect(Validators.normalisePhone('(012) 345 6789'), expected);
      expect(Validators.normalisePhone('60123456789'), expected);
      expect(Validators.normalisePhone('+60123456789'), expected);
    });

    test('returns null for nothing entered', () {
      expect(Validators.normalisePhone(''), isNull);
      expect(Validators.normalisePhone(null), isNull);
      expect(Validators.normalisePhone('   '), isNull);
    });
  });

  group('Validators.fullName', () {
    test('accepts a real name', () {
      expect(Validators.fullName('Adam Rahman'), isNull);
      expect(Validators.fullName('Wei Ling Tan'), isNull);
    });

    test('rejects blank and absurd input', () {
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.fullName('  '), isNotNull);
      expect(Validators.fullName('A'), isNotNull);
      expect(Validators.fullName('x' * 81), isNotNull);
    });
  });

  group('Validators.problemDescription', () {
    test('accepts a description a technician could prepare from', () {
      expect(
        Validators.problemDescription(
          'My laptop turns on but the screen stays black.',
        ),
        isNull,
      );
    });

    test('asks for more when the description says nothing useful', () {
      expect(Validators.problemDescription(''), isNotNull);
      expect(Validators.problemDescription('broken'), isNotNull);
      expect(Validators.problemDescription('x' * 2001), isNotNull);
    });
  });

  group('Validators.required', () {
    test('names the field it is complaining about', () {
      expect(Validators.required('', field: 'Password'), contains('Password'));
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required('something'), isNull);
    });
  });
}
