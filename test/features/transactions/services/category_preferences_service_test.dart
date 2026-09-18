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

  test('adding and removing custom subcategories persists and updates hierarchy', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final service = CategoryPreferencesService();
    addTearDown(service.dispose);

    await service.loadForUser('user-custom-cat');

    // Add custom subcategory under Bills
    await service.addSubcategory(
      parentName: 'Bills',
      categoryName: 'Solar Maintenance',
    );

    expect(service.isCustomCategory('Solar Maintenance'), isTrue);
    expect(service.parentNameFor('Solar Maintenance'), 'Bills');
    expect(service.isExpense('Solar Maintenance'), isTrue);
    expect(
      service.childrenOf('Bills').map((c) => c.name),
      contains('Solar Maintenance'),
    );

    // Verify hierarchy includes it
    final billsOptions = service.hierarchy['Home']?['Bills']?.map((c) => c.name);
    expect(billsOptions, contains('Solar Maintenance'));

    // Remove custom subcategory
    await service.removeSubcategory(
      parentName: 'Bills',
      categoryName: 'Solar Maintenance',
    );

    expect(service.isCustomCategory('Solar Maintenance'), isFalse);
    expect(
      service.childrenOf('Bills').map((c) => c.name),
      isNot(contains('Solar Maintenance')),
    );

    // Add and reload to test persistence
    await service.addSubcategory(
      parentName: 'Bills',
      categoryName: 'Gardener',
    );

    final service2 = CategoryPreferencesService();
    addTearDown(service2.dispose);
    await service2.loadForUser('user-custom-cat');

    expect(service2.isCustomCategory('Gardener'), isTrue);
    expect(
      service2.childrenOf('Bills').map((c) => c.name),
      contains('Gardener'),
    );
  });

  test('income parent categories and their subcategories are recognized as income', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final service = CategoryPreferencesService();
    addTearDown(service.dispose);

    await service.loadForUser('user-income-test');

    // Business is a level-2 parent under 'Money In'
    expect(service.isParentCategory('Business'), isTrue);
    expect(service.isParentCategory('Salary'), isTrue);
    expect(service.modeForParent('Business'), CategoryMode.income);
    expect(service.isExpense('Business'), isFalse);

    // Add custom subcategory under Business
    await service.addSubcategory(
      parentName: 'Business',
      categoryName: 'Online Store',
    );

    expect(service.isCustomCategory('Online Store'), isTrue);
    expect(service.parentNameFor('Online Store'), 'Business');
    expect(service.isExpense('Online Store'), isFalse);
    expect(
      service.childrenOf('Business').firstWhere((c) => c.name == 'Online Store').isExpense,
      isFalse,
    );
    expect(
      service.resolveTransactionTypeForCategory(
        categoryName: 'Online Store',
        transactionIsExpense: true,
      ),
      isFalse,
    );

    // Add custom subcategory under Salary
    await service.addSubcategory(
      parentName: 'Salary',
      categoryName: 'Side Gig',
    );
    expect(service.isExpense('Side Gig'), isFalse);
    expect(
      service.childrenOf('Salary').firstWhere((c) => c.name == 'Side Gig').isExpense,
      isFalse,
    );
  });

  test('loadForUser heals previously poisoned income subcategory classifications', () async {
    // Simulate corrupted storage where an income subcategory was saved with isExpense = true
    FlutterSecureStorage.setMockInitialValues({
      'category_preferences_user-poisoned':
          '{"custom_subcategories":{"Business":["Online Store"]},"classifications":{"Online Store":true}}',
    });

    final service = CategoryPreferencesService();
    addTearDown(service.dispose);

    await service.loadForUser('user-poisoned');

    // The corrupted 'true' should be healed to 'false' based on parent mode
    expect(service.isExpense('Online Store'), isFalse);
    expect(
      service.childrenOf('Business').firstWhere((c) => c.name == 'Online Store').isExpense,
      isFalse,
    );
  });
}

