import 'package:equatable/equatable.dart';

class WealthSummary extends Equatable {
  const WealthSummary({
    required this.cumulativeIncome,
    required this.cumulativeExpense,
    required this.totalAssets,
    required this.openReceivables,
    required this.openPayables,
  });

  final double cumulativeIncome;
  final double cumulativeExpense;
  final double totalAssets;
  final double openReceivables;
  final double openPayables;

  /// Derived Cash = cumulative income - cumulative expense
  double get cash => cumulativeIncome - cumulativeExpense;

  /// Total Wealth = Cash + Assets + Receivables (open khata) - Payables (open khata)
  double get totalWealth => cash + totalAssets + openReceivables - openPayables;

  @override
  List<Object?> get props => [
        cumulativeIncome,
        cumulativeExpense,
        totalAssets,
        openReceivables,
        openPayables,
      ];
}

