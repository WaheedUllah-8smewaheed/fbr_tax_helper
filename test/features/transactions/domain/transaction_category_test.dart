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

  test('housing utilities includes mobile packages', () {
    expect(
      TransactionCategory.childrenOf(
        'Housing & Utils',
      ).map((category) => category.name),
      contains('Mobile Package'),
    );
  });

  test('education categories are available as expenses', () {
    final educationCategories = TransactionCategory.childrenOf('Education');

    expect(
      educationCategories.map((category) => category.name),
      containsAll([
        'Tuition & Fees',
        'Books & Supplies',
        'Courses & Training',
        'Exam Fees',
        'School Transport',
      ]),
    );
    expect(educationCategories.every((category) => category.isExpense), isTrue);
    expect(TransactionCategory.hierarchyPathFor('Tuition & Fees'), [
      'Education & Learning',
      'Education',
      'Tuition & Fees',
    ]);
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
