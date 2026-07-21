import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';

void main() {
  test('dual-mode categories preserve each transaction type in the matching section', () {
    expect(
      CategoryPreferencesService.resolveTransactionType(
        isDualMode: true,
        categoryIsExpense: true,
        transactionIsExpense: false,
      ),
      isFalse,
    );

    expect(
      CategoryPreferencesService.shouldShowInSection(
        isDualMode: true,
        categoryIsExpense: true,
        isExpenseSection: false,
        transactionIsExpense: false,
      ),
      isTrue,
    );

    expect(
      CategoryPreferencesService.shouldShowInSection(
        isDualMode: true,
        categoryIsExpense: true,
        isExpenseSection: true,
        transactionIsExpense: false,
      ),
      isFalse,
    );
  });
}
