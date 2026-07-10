class TransactionCategory {
  const TransactionCategory({required this.name, required this.isExpense});

  final String name;
  final bool isExpense;

  static const salary = TransactionCategory(name: 'Salary', isExpense: false);
  static const investment =
      TransactionCategory(name: 'Investment', isExpense: false);
  static const tax = TransactionCategory(name: 'Tax', isExpense: false);
  static const health = TransactionCategory(name: 'Health', isExpense: true);
  static const foodAndDrinks =
      TransactionCategory(name: 'Food & Drinks', isExpense: true);
  static const shopping = TransactionCategory(name: 'Shopping', isExpense: true);
  static const housingAndUtils =
      TransactionCategory(name: 'Housing & Utils', isExpense: true);
  static const personalCare =
      TransactionCategory(name: 'Personal Care', isExpense: true);
  static const subscriptions =
      TransactionCategory(name: 'Subscriptions', isExpense: true);
  static const giftsAndRewards =
      TransactionCategory(name: 'Gifts & Rewards', isExpense: true);
  static const zakat = TransactionCategory(name: 'Zakat', isExpense: true);
  static const misc = TransactionCategory(name: 'Misc', isExpense: true);

  static const all = <TransactionCategory>[
    salary,
    investment,
    tax,
    health,
    foodAndDrinks,
    shopping,
    housingAndUtils,
    personalCare,
    subscriptions,
    giftsAndRewards,
    zakat,
    misc,
  ];
}
