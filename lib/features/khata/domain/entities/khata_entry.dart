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
    this.description = '',
    this.isPaid = false,
  });

  final int? id;
  final String userId;
  final String title;
  final String party;
  final double amount;
  final bool isPayable;
  final DateTime date;
  final String description;
  final bool isPaid;

  KhataEntry copyWith({
    int? id,
    String? userId,
    String? title,
    String? party,
    double? amount,
    bool? isPayable,
    DateTime? date,
    String? description,
    bool? isPaid,
  }) {
    return KhataEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      party: party ?? this.party,
      amount: amount ?? this.amount,
      isPayable: isPayable ?? this.isPayable,
      date: date ?? this.date,
      description: description ?? this.description,
      isPaid: isPaid ?? this.isPaid,
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
      'description': description,
      'isPaid': isPaid ? 1 : 0,
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
      description: map['description'] as String? ?? '',
      isPaid: (map['isPaid'] as int? ?? 0) == 1,
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
        description,
        isPaid,
      ];
}

