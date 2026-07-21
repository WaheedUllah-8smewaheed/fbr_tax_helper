import 'dart:convert';

import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CategoryPreferencesService extends ChangeNotifier {
  CategoryPreferencesService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, bool> _classifications = {};
  final Set<String> _dualModeCategories = <String>{};

  String? _userId;
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  bool isExpense(String categoryName) {
    return _classifications[categoryName] ??
        TransactionCategory.fromName(categoryName).isExpense;
  }

  bool isDualMode(String categoryName) {
    return _dualModeCategories.contains(categoryName);
  }

  bool resolveTransactionTypeForCategory({
    required String categoryName,
    required bool transactionIsExpense,
  }) {
    return resolveTransactionType(
      isDualMode: isDualMode(categoryName),
      categoryIsExpense: isExpense(categoryName),
      transactionIsExpense: transactionIsExpense,
    );
  }

  bool shouldShowCategoryInSection({
    required String categoryName,
    required bool isExpenseSection,
  }) {
    if (isDualMode(categoryName)) {
      return false;
    }
    return isExpense(categoryName) == isExpenseSection;
  }

  bool shouldShowTransactionInSection({
    required String categoryName,
    required bool isExpenseSection,
    required bool transactionIsExpense,
  }) {
    return shouldShowInSection(
      isDualMode: isDualMode(categoryName),
      categoryIsExpense: isExpense(categoryName),
      isExpenseSection: isExpenseSection,
      transactionIsExpense: transactionIsExpense,
    );
  }

  static bool resolveTransactionType({
    required bool isDualMode,
    required bool categoryIsExpense,
    required bool transactionIsExpense,
  }) {
    if (isDualMode) {
      return transactionIsExpense;
    }
    return categoryIsExpense;
  }

  static bool shouldShowInSection({
    required bool isDualMode,
    required bool categoryIsExpense,
    required bool isExpenseSection,
    required bool transactionIsExpense,
  }) {
    return resolveTransactionType(
          isDualMode: isDualMode,
          categoryIsExpense: categoryIsExpense,
          transactionIsExpense: transactionIsExpense,
        ) ==
        isExpenseSection;
  }

  Future<void> loadForUser(String userId) async {
    if (_userId == userId) return;

    _userId = userId;
    _isLoading = true;
    _loadError = null;
    _classifications.clear();
    _dualModeCategories.clear();
    notifyListeners();

    try {
      final storedValue = await _storage.read(key: _storageKey(userId));
      if (storedValue != null && storedValue.isNotEmpty) {
        final decoded = jsonDecode(storedValue);
        if (decoded is Map<String, dynamic>) {
          if (decoded['classifications'] is Map<String, dynamic>) {
            final classifications =
                decoded['classifications'] as Map<String, dynamic>;
            for (final category in TransactionCategory.all) {
              final value = classifications[category.name];
              if (value is bool) {
                _classifications[category.name] = value;
              }
            }
          } else {
            for (final category in TransactionCategory.all) {
              final value = decoded[category.name];
              if (value is bool) {
                _classifications[category.name] = value;
              }
            }
          }

          final dualModes = decoded['dual_modes'];
          if (dualModes is List) {
            for (final value in dualModes) {
              if (value is String) {
                _dualModeCategories.add(value);
              }
            }
          }
        }
      }
    } catch (error) {
      _loadError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setExpenseClassification(
    String categoryName, {
    required bool isExpense,
  }) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before changing category settings.');
    }

    final hadPreviousValue = _classifications.containsKey(categoryName);
    final previousValue = _classifications[categoryName];
    _classifications[categoryName] = isExpense;
    notifyListeners();

    try {
      await _storage.write(
        key: _storageKey(userId),
        value: jsonEncode(_persistedState),
      );
    } catch (_) {
      if (hadPreviousValue) {
        _classifications[categoryName] = previousValue!;
      } else {
        _classifications.remove(categoryName);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setDualMode(String categoryName, {required bool enabled}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before changing category settings.');
    }

    final hadPreviousValue = _dualModeCategories.contains(categoryName);
    if (enabled) {
      _dualModeCategories.add(categoryName);
    } else {
      _dualModeCategories.remove(categoryName);
    }
    notifyListeners();

    try {
      await _storage.write(
        key: _storageKey(userId),
        value: jsonEncode(_persistedState),
      );
    } catch (_) {
      if (hadPreviousValue) {
        _dualModeCategories.add(categoryName);
      } else {
        _dualModeCategories.remove(categoryName);
      }
      notifyListeners();
      rethrow;
    }
  }

  Map<String, dynamic> get _persistedState => {
    'classifications': {
      for (final entry in _classifications.entries) entry.key: entry.value,
    },
    'dual_modes': _dualModeCategories.toList(),
  };

  String _storageKey(String userId) => 'category_preferences_$userId';
}
