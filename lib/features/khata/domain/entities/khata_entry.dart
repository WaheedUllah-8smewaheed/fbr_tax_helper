import 'package:equatable/equatable.dart';

class KhataEntry extends Equatable {
  const KhataEntry({
    this.id,
    required this.userId,
    required this.title,
    required this.party,
    required this.amount,
    required this.isPayable,
    required this.date,
    this.dueDate,
    this.description = '',
    this.isPaid = false,
    this.settledAmount = 0.0,
    this.isWrittenOff = false,
    this.fromIncome = false,
  });

  final int? id;
  final String userId;
  final String title;
  final String party;
  final double amount;
  final bool isPayable;
  final DateTime date;
  final DateTime? dueDate;
  final String description;
  final bool isPaid;
  final double settledAmount;
  final bool isWrittenOff;
  final bool fromIncome;

  double get remainingAmount => (amount - settledAmount).clamp(0.0, amount);

  KhataEntry copyWith({
    int? id,
    String? userId,
    String? title,
    String? party,
    double? amount,
    bool? isPayable,
    DateTime? date,
    DateTime? dueDate,
    String? description,
    bool? isPaid,
    double? settledAmount,
    bool? isWrittenOff,
    bool? fromIncome,
  }) {
    return KhataEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      party: party ?? this.party,
      amount: amount ?? this.amount,
      isPayable: isPayable ?? this.isPayable,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      isPaid: isPaid ?? this.isPaid,
      settledAmount: settledAmount ?? this.settledAmount,
      isWrittenOff: isWrittenOff ?? this.isWrittenOff,
      fromIncome: fromIncome ?? this.fromIncome,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'title': title,
      'party': party,
      'amount': amount,
      'isPayable': isPayable ? 1 : 0,
      'date': date.toIso8601String(),
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      'description': description,
      'isPaid': isPaid ? 1 : 0,
      'settledAmount': settledAmount,
      'isWrittenOff': isWrittenOff ? 1 : 0,
      'fromIncome': fromIncome ? 1 : 0,
    };
  }

  factory KhataEntry.fromMap(Map<String, dynamic> map) {
    return KhataEntry(
      id: map['id'] as int?,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      party: map['party'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      isPayable: (map['isPayable'] as int? ?? 1) == 1,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'] as String)
          : null,
      description: map['description'] as String? ?? '',
      isPaid: (map['isPaid'] as int? ?? 0) == 1,
      settledAmount: (map['settledAmount'] as num?)?.toDouble() ?? 0.0,
      isWrittenOff: (map['isWrittenOff'] as int? ?? 0) == 1,
      fromIncome: (map['fromIncome'] as int? ?? 0) == 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        party,
        amount,
        isPayable,
        date,
        dueDate,
        description,
        isPaid,
        settledAmount,
        isWrittenOff,
        fromIncome,
      ];
}

