import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('salary is income and tax is expense', () {
    expect(TransactionCategory.fromName('Salary').isExpense, isFalse);
    expect(TransactionCategory.fromName('Tax').isExpense, isTrue);
  });

  test('unknown categories safely fall back to miscellaneous expense', () {
    expect(TransactionCategory.fromName('Unknown'), TransactionCategory.misc);
    expect(TransactionCategory.fromName('Unknown').isExpense, isTrue);
  });
}
