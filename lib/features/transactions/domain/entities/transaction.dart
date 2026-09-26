import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  const Transaction({
    this.id,
    required this.userId,
    required this.title,
    required this.beneficiary,
    required this.purpose,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.category,
    this.receiptImagePath,
    this.khataEntryId,
    this.assetId,
    this.linkedCounterpartyOrAsset,
  });

  final int? id;
  final String userId;
  final String title;
  final String beneficiary;
  final String purpose;
  final double amount;
  final bool isExpense;
  final DateTime date;
  final String category;
  final String? receiptImagePath;
  final int? khataEntryId;
  final int? assetId;
  final String? linkedCounterpartyOrAsset;

  Transaction copyWith({
    int? id,
    String? userId,
    String? title,
    String? beneficiary,
    String? purpose,
    double? amount,
    bool? isExpense,
    DateTime? date,
    String? category,
    String? receiptImagePath,
    int? khataEntryId,
    int? assetId,
    String? linkedCounterpartyOrAsset,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      beneficiary: beneficiary ?? this.beneficiary,
      purpose: purpose ?? this.purpose,
      amount: amount ?? this.amount,
      isExpense: isExpense ?? this.isExpense,
      date: date ?? this.date,
      category: category ?? this.category,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      khataEntryId: khataEntryId ?? this.khataEntryId,
      assetId: assetId ?? this.assetId,
      linkedCounterpartyOrAsset:
          linkedCounterpartyOrAsset ?? this.linkedCounterpartyOrAsset,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    beneficiary,
    purpose,
    amount,
    isExpense,
    date,
    category,
    receiptImagePath,
    khataEntryId,
    assetId,
    linkedCounterpartyOrAsset,
  ];
}
