import 'package:equatable/equatable.dart';

enum AssetCategory {
  cash,
  bank,
  property,
  vehicle,
  investment,
  other;

  String get displayName => switch (this) {
        AssetCategory.cash => 'Cash',
        AssetCategory.bank => 'Bank',
        AssetCategory.property => 'Property',
        AssetCategory.vehicle => 'Vehicle',
        AssetCategory.investment => 'Investment',
        AssetCategory.other => 'Other',
      };

  static AssetCategory fromString(String? value) {
    if (value == null) return AssetCategory.other;
    return AssetCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == value.toLowerCase() ||
             c.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => AssetCategory.other,
    );
  }
}

class Asset extends Equatable {
  const Asset({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
  });

  final int? id;
  final String userId;
  final String name;
  final AssetCategory category;
  final double value;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;

  Asset copyWith({
    int? id,
    String? userId,
    String? name,
    AssetCategory? category,
    double? value,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
  }) {
    return Asset(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'name': name,
      'category': category.displayName,
      'value': value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as int?,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: AssetCategory.fromString(map['category'] as String?),
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      description: map['description'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        category,
        value,
        createdAt,
        updatedAt,
        description,
      ];
}

