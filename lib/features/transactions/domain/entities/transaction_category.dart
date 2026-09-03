class TransactionCategory {
  const TransactionCategory({required this.name, required this.isExpense});

  final String name;
  final bool isExpense;

  static const salary = TransactionCategory(name: 'Salary', isExpense: false);
  static const investment = TransactionCategory(
    name: 'Investment Profit',
    isExpense: false,
  );
  static const tax = TransactionCategory(name: 'Income Tax', isExpense: true);
  static const health = TransactionCategory(name: 'Doctor', isExpense: true);
  static const foodAndDrinks = TransactionCategory(
    name: 'Groceries',
    isExpense: true,
  );
  static const shopping = TransactionCategory(name: 'Clothes', isExpense: true);
  static const housingAndUtils = TransactionCategory(
    name: 'Electricity',
    isExpense: true,
  );
  static const rent = TransactionCategory(name: 'House Rent', isExpense: true);
  static const transport = TransactionCategory(name: 'Fuel', isExpense: true);
  static const personalCare = TransactionCategory(
    name: 'Salon',
    isExpense: true,
  );
  static const subscriptions = TransactionCategory(
    name: 'Streaming',
    isExpense: true,
  );
  static const giftsAndRewards = TransactionCategory(
    name: 'Gift Given',
    isExpense: true,
  );
  static const zakat = TransactionCategory(name: 'Zakat', isExpense: true);
  static const monthlyHomePayment = TransactionCategory(
    name: 'Monthly Home Payment',
    isExpense: true,
  );
  static const committee = TransactionCategory(
    name: 'Committee',
    isExpense: true,
  );
  static const misc = TransactionCategory(name: 'Other', isExpense: true);

  static const hierarchy = <String, Map<String, List<TransactionCategory>>>{
    'Money In': {
      'Salary': [
        salary,
        TransactionCategory(name: 'Bonus', isExpense: false),
        TransactionCategory(name: 'Overtime', isExpense: false),
        TransactionCategory(name: 'Allowance', isExpense: false),
      ],
      'Business': [
        TransactionCategory(name: 'Business Income', isExpense: false),
        TransactionCategory(name: 'Freelance Income', isExpense: false),
        TransactionCategory(name: 'Rent Received', isExpense: false),
        investment,
      ],
    },
    'Home': {
      'Bills': [
        housingAndUtils,
        TransactionCategory(name: 'Gas', isExpense: true),
        TransactionCategory(name: 'Water', isExpense: true),
        TransactionCategory(name: 'Mobile', isExpense: true),
        TransactionCategory(name: 'Internet', isExpense: true),
        TransactionCategory(name: 'Home Repair', isExpense: true),
      ],
      'Rent': [
        rent,
        TransactionCategory(name: 'Office Rent', isExpense: true),
        TransactionCategory(name: 'Deposit', isExpense: true),
      ],
    },
    'Travel': {
      'Travel': [
        transport,
        TransactionCategory(name: 'Vehicle Repair', isExpense: true),
        TransactionCategory(name: 'Vehicle Tax', isExpense: true),
        TransactionCategory(name: 'Transport Fare', isExpense: true),
        TransactionCategory(name: 'Parking', isExpense: true),
        TransactionCategory(name: 'Picnic/Tour', isExpense: true),
      ],
    },
    'Food': {
      'Food': [
        foodAndDrinks,
        TransactionCategory(name: 'Restaurant', isExpense: true),
        TransactionCategory(name: 'Food Delivery', isExpense: true),
      ],
    },
    'Shopping': {
      'Shopping': [
        shopping,
        TransactionCategory(name: 'Electronics', isExpense: true),
        TransactionCategory(name: 'Home Items', isExpense: true),
      ],
    },
    'Health': {
      'Health': [
        health,
        TransactionCategory(name: 'Medicine', isExpense: true),
        TransactionCategory(name: 'Hospital', isExpense: true),
        TransactionCategory(name: 'Insurance', isExpense: true),
      ],
    },
    'Education': {
      'Education': [
        TransactionCategory(name: 'School Fee', isExpense: true),
        TransactionCategory(name: 'Books', isExpense: true),
        TransactionCategory(name: 'Courses', isExpense: true),
        TransactionCategory(name: 'Exam Fee', isExpense: true),
        TransactionCategory(name: 'Transport', isExpense: true),
      ],
    },
    'Personal Care': {
      'Personal Care': [
        personalCare,
        TransactionCategory(name: 'Beauty Products', isExpense: true),
        TransactionCategory(name: 'Gym', isExpense: true),
      ],
    },
    'Entertainment': {
      'Entertainment': [
        subscriptions,
        TransactionCategory(name: 'Apps', isExpense: true),
        TransactionCategory(name: 'Membership', isExpense: true),
      ],
    },
    'Gifts': {
      'Gifts': [
        giftsAndRewards,
        TransactionCategory(name: 'Gift Received', isExpense: false),
      ],
    },
    'Charity': {
      'Charity': [
        zakat,
        TransactionCategory(name: 'Sadaqah', isExpense: true),
        TransactionCategory(name: 'Donation', isExpense: true),
      ],
    },
    'Taxes': {
      'Taxes': [
        tax,
        TransactionCategory(name: 'Property Tax', isExpense: true),
        TransactionCategory(name: 'Sales Tax', isExpense: true),
        TransactionCategory(name: 'Vehicle Tax', isExpense: true),
      ],
    },
    'Banking': {
      'Banking': [
        TransactionCategory(name: 'Bank Charges', isExpense: true),
        TransactionCategory(name: 'Loan Payment', isExpense: true),
      ],
    },
    'Commitments': {
      'Commitments': [
        monthlyHomePayment,
        committee,
      ],
    },
    'Others': {
      'Others': [misc],
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
        if (parent.value.any((category) => category.name == categoryName)) {
          return [superCategory.key, parent.key, categoryName];
        }
        if (parent.key == categoryName) {
          return [superCategory.key, parent.key];
        }
      }
    }
    return [categoryName];
  }

  static String displayPathFor(String categoryName) {
    return hierarchyPathFor(categoryName).join(' > ');
  }

  // Kept so transactions saved by earlier app versions remain readable.
  static const legacy = <TransactionCategory>[
    TransactionCategory(name: 'Basic Pay', isExpense: false),
    TransactionCategory(name: 'Allowances', isExpense: false),
    TransactionCategory(name: 'Investment', isExpense: false),
    TransactionCategory(name: 'Capital Gains', isExpense: false),
    TransactionCategory(name: 'Rental Income', isExpense: false),
    TransactionCategory(name: 'Interest/Profit', isExpense: false),
    TransactionCategory(name: 'Tax', isExpense: true),
    TransactionCategory(name: 'Health', isExpense: true),
    TransactionCategory(name: 'Food & Drinks', isExpense: true),
    TransactionCategory(name: 'Clothing', isExpense: true),
    TransactionCategory(name: 'Housing & Utils', isExpense: true),
    TransactionCategory(name: 'Rent', isExpense: true),
    TransactionCategory(name: 'Personal Care', isExpense: true),
    TransactionCategory(name: 'Subscriptions', isExpense: true),
    TransactionCategory(name: 'Gifts & Rewards', isExpense: true),
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
