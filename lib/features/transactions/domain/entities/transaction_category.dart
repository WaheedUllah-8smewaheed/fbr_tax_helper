class TransactionCategory {
  const TransactionCategory({required this.name, required this.isExpense});

  final String name;
  final bool isExpense;

  static const salary = TransactionCategory(
    name: 'Basic Pay',
    isExpense: false,
  );
  static const investment = TransactionCategory(
    name: 'Dividends',
    isExpense: false,
  );
  static const tax = TransactionCategory(name: 'Income Tax', isExpense: true);
  static const health = TransactionCategory(
    name: 'Doctor/Consultation',
    isExpense: true,
  );
  static const foodAndDrinks = TransactionCategory(
    name: 'Groceries',
    isExpense: true,
  );
  static const shopping = TransactionCategory(
    name: 'Clothing',
    isExpense: true,
  );
  static const housingAndUtils = TransactionCategory(
    name: 'Electricity',
    isExpense: true,
  );
  static const rent = TransactionCategory(name: 'House Rent', isExpense: true);
  static const transport = TransactionCategory(name: 'Fuel', isExpense: true);
  static const personalCare = TransactionCategory(
    name: 'Salon/Grooming',
    isExpense: true,
  );
  static const subscriptions = TransactionCategory(
    name: 'Streaming (Netflix, etc.)',
    isExpense: true,
  );
  static const giftsAndRewards = TransactionCategory(
    name: 'Given',
    isExpense: true,
  );
  static const zakat = TransactionCategory(
    name: 'Zakat on Savings',
    isExpense: true,
  );
  static const misc = TransactionCategory(
    name: 'Other',
    isExpense: true,
  );

  static const hierarchy = <String, Map<String, List<TransactionCategory>>>{
    'Income': {
      'Salary': [
        salary,
        TransactionCategory(name: 'Bonus', isExpense: false),
        TransactionCategory(name: 'Overtime', isExpense: false),
        TransactionCategory(name: 'Allowances', isExpense: false),
      ],
      'Investment': [
        investment,
        TransactionCategory(name: 'Capital Gains', isExpense: false),
        TransactionCategory(name: 'Rental Income', isExpense: false),
        TransactionCategory(name: 'Interest/Profit', isExpense: false),
      ],
    },
    'Housing & Transport': {
      'Housing & Utils': [
        housingAndUtils,
        TransactionCategory(name: 'Gas', isExpense: true),
        TransactionCategory(name: 'Water', isExpense: true),
        TransactionCategory(name: 'Mobile Package', isExpense: true),
        TransactionCategory(name: 'Internet & Cable', isExpense: true),
        TransactionCategory(name: 'Maintenance/Repairs', isExpense: true),
      ],
      'Rent': [
        rent,
        TransactionCategory(name: 'Office Rent', isExpense: true),
        TransactionCategory(name: 'Security Deposit', isExpense: true),
      ],
      'Transport': [
        transport,
        TransactionCategory(name: 'Vehicle Maintenance', isExpense: true),
        TransactionCategory(name: 'Vehicle Tax/Token', isExpense: true),
        TransactionCategory(name: 'Public Transport/Fare', isExpense: true),
        TransactionCategory(name: 'Parking & Tolls', isExpense: true),
      ],
    },
    'Food & Lifestyle': {
      'Food & Drinks': [
        foodAndDrinks,
        TransactionCategory(name: 'Dining Out', isExpense: true),
        TransactionCategory(name: 'Delivery/Takeout', isExpense: true),
      ],
      'Shopping': [
        shopping,
        TransactionCategory(name: 'Electronics', isExpense: true),
        TransactionCategory(name: 'Home Essentials', isExpense: true),
      ],
      'Personal Care': [
        personalCare,
        TransactionCategory(name: 'Skincare/Cosmetics', isExpense: true),
        TransactionCategory(name: 'Gym/Fitness', isExpense: true),
      ],
      'Subscriptions': [
        subscriptions,
        TransactionCategory(name: 'Software/Apps', isExpense: true),
        TransactionCategory(name: 'Memberships', isExpense: true),
      ],
    },
    'Wellness & Giving': {
      'Health': [
        health,
        TransactionCategory(name: 'Medicine', isExpense: true),
        TransactionCategory(name: 'Hospital/Surgery', isExpense: true),
        TransactionCategory(name: 'Insurance Premium', isExpense: true),
      ],
      'Zakat': [
        zakat,
        TransactionCategory(name: 'Zakat on Gold/Assets', isExpense: true),
        TransactionCategory(name: 'Sadaqah', isExpense: true),
      ],
      'Gifts & Rewards': [
        giftsAndRewards,
        TransactionCategory(name: 'Received', isExpense: false),
      ],
    },
    'Financial Obligations': {
      'Tax': [
        tax,
        TransactionCategory(name: 'Property Tax', isExpense: true),
        TransactionCategory(name: 'Salary Tax (withholding)', isExpense: true),
        TransactionCategory(name: 'Sales Tax/GST', isExpense: true),
      ],
      'Misc': [
        TransactionCategory(name: 'Bank Charges/Fees', isExpense: true),
        TransactionCategory(name: 'Loan Repayment', isExpense: true),
        misc,
      ],
    },
  };

  static final List<TransactionCategory> all = List.unmodifiable(
    hierarchy.values.expand(
      (parents) => parents.values.expand((categories) => categories),
    ),
  );

  static String? parentNameFor(String categoryName) {
    for (final parents in hierarchy.values) {
      for (final parent in parents.entries) {
        if (parent.value.any((category) => category.name == categoryName)) {
          return parent.key;
        }
      }
    }
    return null;
  }

  static List<TransactionCategory> childrenOf(String parentName) {
    for (final parents in hierarchy.values) {
      final children = parents[parentName];
      if (children != null) return children;
    }
    return const [];
  }

  static List<String> hierarchyPathFor(String categoryName) {
    for (final superCategory in hierarchy.entries) {
      for (final parent in superCategory.value.entries) {
        if (parent.key == categoryName) {
          return [superCategory.key, parent.key];
        }
        if (parent.value.any((category) => category.name == categoryName)) {
          return [superCategory.key, parent.key, categoryName];
        }
      }
    }
    return [categoryName];
  }

  static String displayPathFor(String categoryName) {
    return hierarchyPathFor(categoryName).join(' > ');
  }

  static const legacy = <TransactionCategory>[
    TransactionCategory(name: 'Salary', isExpense: false),
    TransactionCategory(name: 'Investment', isExpense: false),
    TransactionCategory(name: 'Tax', isExpense: true),
    TransactionCategory(name: 'Health', isExpense: true),
    TransactionCategory(name: 'Food & Drinks', isExpense: true),
    TransactionCategory(name: 'Shopping', isExpense: true),
    TransactionCategory(name: 'Housing & Utils', isExpense: true),
    TransactionCategory(name: 'Rent', isExpense: true),
    TransactionCategory(name: 'Transport', isExpense: true),
    TransactionCategory(name: 'Personal Care', isExpense: true),
    TransactionCategory(name: 'Subscriptions', isExpense: true),
    TransactionCategory(name: 'Gifts & Rewards', isExpense: true),
    TransactionCategory(name: 'Zakat', isExpense: true),
    TransactionCategory(name: 'Misc', isExpense: true),
    TransactionCategory(name: 'Uncategorized', isExpense: true),
  ];

  static TransactionCategory fromName(String name) {
    return [
      ...all,
      ...legacy,
    ].firstWhere((category) => category.name == name, orElse: () => misc);
  }
}
