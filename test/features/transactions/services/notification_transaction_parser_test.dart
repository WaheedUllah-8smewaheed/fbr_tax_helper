import 'package:fbr_tax_helper/features/transactions/services/notification_transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses sent payment notifications as expenses', () {
    final details = NotificationTransactionParser.parse(
      'Rs. 230.0 sent to amin',
    );

    expect(details, isNotNull);
    expect(details!.amount, 230);
    expect(details.isExpense, isTrue);
    expect(details.beneficiary, 'amin');
  });

  test(
    'uses only first sent-to name as beneficiary and comma text as title',
    () {
      final details = NotificationTransactionParser.parse(
        'Rs. 230.0 sent to Amin Khan, Bank Alfalah account transfer',
      );

      expect(details, isNotNull);
      expect(details!.amount, 230);
      expect(details.isExpense, isTrue);
      expect(details.beneficiary, 'Amin');
      expect(details.title, 'Bank Alfalah account transfer');
    },
  );

  test('parses paid-for payment notifications as expenses', () {
    final details = NotificationTransactionParser.parse(
      'Rs. 4324 paid for monthly social, for 342423423 on date,',
    );

    expect(details, isNotNull);
    expect(details!.amount, 4324);
    expect(details.isExpense, isTrue);
    expect(details.purpose, 'monthly social');
    expect(details.beneficiary, '342423423');
  });

  test('parses received payment notifications as income', () {
    final details = NotificationTransactionParser.parse(
      'PKR 34 recieved from dfgd',
    );

    expect(details, isNotNull);
    expect(details!.amount, 34);
    expect(details.isExpense, isFalse);
    expect(details.beneficiary, 'dfgd');
  });

  test('parses sent-to alerts with the currency after sent', () {
    final details = NotificationTransactionParser.parse(
      'You sent PKR 900 to Ali on 21 July.',
    );

    expect(details, isNotNull);
    expect(details!.amount, 900);
    expect(details.isExpense, isTrue);
    expect(details.beneficiary, 'Ali');
  });

  test('parses correctly spelled received-from alerts', () {
    final details = NotificationTransactionParser.parse(
      'You have received PKR 1,200 from Sana.',
    );

    expect(details, isNotNull);
    expect(details!.amount, 1200);
    expect(details.isExpense, isFalse);
    expect(details.beneficiary, 'Sana');
  });

  test('keeps no-amount notification imports reviewable', () {
    final details = NotificationTransactionParser.parse('PKR sent to afdsf5');

    expect(details, isNotNull);
    expect(details!.amount, isNull);
    expect(details.isExpense, isTrue);
    expect(details.beneficiary, 'afdsf5');
  });

  test('parses debited bank alerts as expenses', () {
    final details = NotificationTransactionParser.parse(
      'Your account has been debited by PKR 1,250.00 at ABC STORE.',
    );

    expect(details, isNotNull);
    expect(details!.amount, 1250);
    expect(details.isExpense, isTrue);
    expect(details.beneficiary, 'ABC STORE');
  });

  test('parses credited bank alerts as income', () {
    final details = NotificationTransactionParser.parse(
      'PKR 5,000.00 has been credited to your account.',
    );

    expect(details, isNotNull);
    expect(details!.amount, 5000);
    expect(details.isExpense, isFalse);
  });

  test('parses is-credited alerts as income', () {
    final details = NotificationTransactionParser.parse(
      'Your account is credited with PKR 2,400 from Ahmed.',
    );

    expect(details, isNotNull);
    expect(details!.amount, 2400);
    expect(details.isExpense, isFalse);
    expect(details.beneficiary, 'Ahmed');
  });

  test('parses transfered spelling as an expense', () {
    final details = NotificationTransactionParser.parse(
      'PKR 750 transfered to Bilal.',
    );

    expect(details, isNotNull);
    expect(details!.amount, 750);
    expect(details.isExpense, isTrue);
    expect(details.beneficiary, 'Bilal');
  });
}
