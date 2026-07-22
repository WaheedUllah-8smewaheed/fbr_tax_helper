import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('salary is income and tax is expense', () {
    expect(TransactionCategory.fromName('Salary').isExpense, isFalse);
    expect(TransactionCategory.fromName('Tax').isExpense, isTrue);
    expect(TransactionCategory.fromName('Rent').isExpense, isTrue);
    expect(TransactionCategory.fromName('Transport').isExpense, isTrue);
  });

  test('unknown categories safely fall back to miscellaneous expense', () {
    expect(TransactionCategory.fromName('Unknown'), TransactionCategory.misc);
    expect(TransactionCategory.fromName('Unknown').isExpense, isTrue);
  });

  test('builds printable paths for new and legacy categories', () {
    expect(TransactionCategory.hierarchyPathFor('Fuel'), [
      'Housing & Transport',
      'Transport',
      'Fuel',
    ]);
    expect(
      TransactionCategory.displayPathFor('Basic Pay'),
      'Income > Salary > Basic Pay',
    );
    expect(TransactionCategory.hierarchyPathFor('Salary'), [
      'Income',
      'Salary',
    ]);
    expect(TransactionCategory.hierarchyPathFor('Old Custom'), ['Old Custom']);
  });
}
