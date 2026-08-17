import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  test('level-2 modes apply to their level-3 categories', () {
    final service = CategoryPreferencesService();
    addTearDown(service.dispose);

    expect(service.modeForParent('Salary'), CategoryMode.income);
    expect(service.isExpense('Salary'), isFalse);
    expect(service.modeForParent('Travel'), CategoryMode.expense);
    expect(service.isExpense('Fuel'), isTrue);
    expect(service.isExpense('Picnic/Tour'), isTrue);
    expect(service.modeForParent('Gifts'), CategoryMode.both);
    expect(service.isDualMode('Gift Given'), isTrue);
    expect(service.isDualMode('Gift Received'), isTrue);
  });

  test('changing a level-2 category to expense updates every child', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final service = CategoryPreferencesService();
    addTearDown(service.dispose);

    await service.loadForUser('user-1');
    await service.setParentMode('Salary', mode: CategoryMode.expense);

    expect(service.modeForParent('Salary'), CategoryMode.expense);
    expect(service.isExpense('Salary'), isTrue);
    expect(service.isExpense('Bonus'), isTrue);
    expect(service.isDualMode('Salary'), isFalse);
    expect(
      service.shouldShowCategoryInSection(
        categoryName: 'Salary',
        isExpenseSection: true,
      ),
      isTrue,
    );
  });

  test('level-2 toggle hides and restores every child category', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final service = CategoryPreferencesService();
    addTearDown(service.dispose);

    await service.loadForUser('user-parent-toggle');
    expect(service.isParentEnabled('Education'), isTrue);

    await service.setParentEnabled('Education', enabled: false);

    expect(service.isParentEnabled('Education'), isFalse);
    for (final category in [
      'School Fee',
      'Books',
      'Courses',
      'Exam Fee',
      'Transport',
    ]) {
      expect(service.isEnabled(category), isFalse);
    }

    await service.setParentEnabled('Education', enabled: true);

    expect(service.isParentEnabled('Education'), isTrue);
    expect(service.isEnabled('School Fee'), isTrue);
    expect(service.isEnabled('Transport'), isTrue);
  });

  test(
    'dual-mode categories preserve each transaction type in the matching section',
    () {
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
    },
  );
}
