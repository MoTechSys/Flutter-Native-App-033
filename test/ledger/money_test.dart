import 'package:flutter_test/flutter_test.dart';
import 'package:sijil/core/money/arabic_words.dart';
import 'package:sijil/core/money/currency.dart';
import 'package:sijil/core/money/money.dart';
import 'package:sijil/core/money/money_format.dart';

void main() {
  group('Money (R2, R4)', () {
    test('add/sub same currency', () {
      final a = const Money(1000, Currency.yer);
      final b = const Money(250, Currency.yer);
      expect((a + b).minor, 1250);
      expect((a - b).minor, 750);
      expect((b - a).minor, -750);
    });

    test('mixing currencies throws (edge #15)', () {
      final a = const Money(1000, Currency.yer);
      final b = const Money(1000, Currency.sar);
      expect(() => a + b, throwsA(isA<CurrencyMismatchError>()));
      expect(() => a - b, throwsA(isA<CurrencyMismatchError>()));
      expect(() => a > b, throwsA(isA<CurrencyMismatchError>()));
    });

    test('parseMajor YER (no decimals)', () {
      expect(Money.parseMajor('3000', Currency.yer).minor, 3000);
      expect(Money.parseMajor('3,000', Currency.yer).minor, 3000);
      expect(() => Money.parseMajor('3.5', Currency.yer), throwsFormatException);
    });

    test('parseMajor SAR (2 decimals)', () {
      expect(Money.parseMajor('12.34', Currency.sar).minor, 1234);
      expect(Money.parseMajor('12', Currency.sar).minor, 1200);
      expect(Money.parseMajor('12.5', Currency.sar).minor, 1250);
      expect(() => Money.parseMajor('12.345', Currency.sar), throwsFormatException);
    });

    test('parse rejects garbage', () {
      expect(() => Money.parseMajor('abc', Currency.yer), throwsFormatException);
      expect(() => Money.parseMajor('', Currency.yer), throwsFormatException);
      expect(() => Money.parseMajor('1.2.3', Currency.sar), throwsFormatException);
    });

    test('convert with fraction rate, half-even rounding', () {
      // 1 SAR = 400 YER exactly: 12.34 SAR -> 4936 YER
      final sar = const Money(1234, Currency.sar);
      expect(sar.convert(Currency.yer, 400, 1).minor, 4936);
      // 1000 YER -> SAR at 1/400: 2.50 SAR = 250 minor
      expect(const Money(1000, Currency.yer).convert(Currency.sar, 1, 400).minor, 250);
      // half-even: 1 YER -> 0.0025 SAR = 0.25 minor -> 0
      expect(const Money(1, Currency.yer).convert(Currency.sar, 1, 400).minor, 0);
      // 3 YER -> 0.75 minor -> 1
      expect(const Money(3, Currency.yer).convert(Currency.sar, 1, 400).minor, 1);
      // exactly .5 -> even: 2 YER -> 0.5 minor -> 0 ; 6 YER -> 1.5 -> 2
      expect(const Money(2, Currency.yer).convert(Currency.sar, 1, 400).minor, 0);
      expect(const Money(6, Currency.yer).convert(Currency.sar, 1, 400).minor, 2);
    });

    test('convert rejects zero denominator', () {
      expect(() => const Money(1, Currency.yer).convert(Currency.sar, 1, 0),
          throwsArgumentError);
    });
  });

  group('MoneyFormat (edge #16)', () {
    test('grouping and sign', () {
      expect(MoneyFormat.amount(const Money(1234567, Currency.yer)), '1,234,567');
      expect(MoneyFormat.amount(const Money(-500, Currency.yer)), '−500');
      expect(MoneyFormat.amount(const Money(0, Currency.yer)), '0');
      expect(MoneyFormat.amount(const Money(999, Currency.yer)), '999');
      expect(MoneyFormat.amount(const Money(1000, Currency.yer)), '1,000');
    });
    test('two-decimal currencies', () {
      expect(MoneyFormat.amount(const Money(12345, Currency.sar)), '123.45');
      expect(MoneyFormat.amount(const Money(5, Currency.usd)), '0.05');
      expect(MoneyFormat.amount(const Money(100, Currency.usd)), '1.00');
    });
    test('with symbol', () {
      expect(MoneyFormat.withSymbol(const Money(3000, Currency.yer)), '3,000 ر.ي');
    });
    test('arabic digits round-trip', () {
      expect(MoneyFormat.amount(const Money(1234, Currency.yer), arabicDigits: true), '١,٢٣٤');
      expect(MoneyFormat.parse('١٢٣٤', Currency.yer).minor, 1234);
      expect(MoneyFormat.parse('١٢٫٣٤', Currency.sar).minor, 1234);
    });
  });

  group('ArabicWords (TTS / receipts)', () {
    test('basic numbers', () {
      expect(ArabicWords.integer(0), 'صفر');
      expect(ArabicWords.integer(1), 'واحد');
      expect(ArabicWords.integer(11), 'أحد عشر');
      expect(ArabicWords.integer(20), 'عشرون');
      expect(ArabicWords.integer(25), 'خمسة وعشرون');
      expect(ArabicWords.integer(100), 'مائة');
      expect(ArabicWords.integer(250), 'مائتان وخمسون');
      expect(ArabicWords.integer(999), 'تسعمائة وتسعة وتسعون');
    });
    test('thousands agreement', () {
      expect(ArabicWords.integer(1000), 'ألف');
      expect(ArabicWords.integer(2000), 'ألفان');
      expect(ArabicWords.integer(3000), 'ثلاثة آلاف');
      expect(ArabicWords.integer(3500), 'ثلاثة آلاف وخمسمائة');
      expect(ArabicWords.integer(11000), 'أحد عشر ألفاً');
      expect(ArabicWords.integer(245000), 'مائتان وخمسة وأربعون ألفاً');
      expect(ArabicWords.integer(1000000), 'مليون');
    });
    test('money words', () {
      expect(ArabicWords.money(const Money(3500, Currency.yer)),
          'ثلاثة آلاف وخمسمائة ريال يمني');
      expect(ArabicWords.money(const Money(1250, Currency.sar)),
          'اثنا عشر ريال سعودي وخمسون هللة');
      expect(ArabicWords.money(const Money(-500, Currency.yer)), 'ناقص خمسمائة ريال يمني');
    });
  });
}
