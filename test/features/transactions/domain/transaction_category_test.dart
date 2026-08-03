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
    expect(TransactionCategory.misc.name, 'Other');
    expect(TransactionCategory.fromName('Uncategorized').name, 'Uncategorized');
  });

  test('home bills include mobile', () {
    expect(
      TransactionCategory.childrenOf('Bills').map((category) => category.name),
      contains('Mobile'),
    );
  });

  test('education categories are available as expenses', () {
    final educationCategories = TransactionCategory.childrenOf('Education');

    expect(
      educationCategories.map((category) => category.name),
      containsAll(['School Fee', 'Books', 'Courses', 'Exam Fee', 'Transport']),
    );
    expect(educationCategories.every((category) => category.isExpense), isTrue);
    expect(TransactionCategory.hierarchyPathFor('School Fee'), [
      'Education',
      'Education',
      'School Fee',
    ]);
  });

  test('builds printable paths for new and legacy categories', () {
    expect(TransactionCategory.hierarchyPathFor('Fuel'), [
      'Travel',
      'Travel',
      'Fuel',
    ]);
    expect(
      TransactionCategory.displayPathFor('Salary'),
      'Money In > Salary > Salary',
    );
    expect(TransactionCategory.hierarchyPathFor('Salary'), [
      'Money In',
      'Salary',
      'Salary',
    ]);
    expect(TransactionCategory.hierarchyPathFor('Old Custom'), ['Old Custom']);
  });
}
