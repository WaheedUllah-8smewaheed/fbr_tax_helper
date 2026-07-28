import 'dart:convert';

import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum CategoryMode { income, expense, both }

class CategoryPreferencesService extends ChangeNotifier {
  CategoryPreferencesService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, bool> _classifications = {};
  final Set<String> _dualModeCategories = <String>{};
  final Set<String> _disabledCategories = <String>{};
  final Map<String, CategoryMode> _groupModes = {};

  String? _userId;
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  bool isExpense(String categoryName) {
    final groupMode = _modeForCategory(categoryName);
    if (groupMode == CategoryMode.income) return false;
    if (groupMode == CategoryMode.expense) return true;
    return _classifications[categoryName] ??
        TransactionCategory.fromName(categoryName).isExpense;
  }

  bool isDualMode(String categoryName) {
    final groupMode = _modeForCategory(categoryName);
    if (groupMode != null) return groupMode == CategoryMode.both;
    return _dualModeCategories.contains(categoryName);
  }

  CategoryMode? _modeForCategory(String categoryName) {
    final parentName = TransactionCategory.parentNameFor(categoryName);
    return parentName == null ? null : modeForParent(parentName);
  }

  CategoryMode modeForParent(String parentName) {
    final storedMode = _groupModes[parentName];
    if (storedMode != null) return storedMode;
    final children = TransactionCategory.childrenOf(parentName);
    final hasIncome = children.any((category) => !category.isExpense);
    final hasExpense = children.any((category) => category.isExpense);
    if (hasIncome && hasExpense) return CategoryMode.both;
    return hasExpense ? CategoryMode.expense : CategoryMode.income;
  }

  bool isEnabled(String categoryName) {
    return !_disabledCategories.contains(categoryName);
  }

  bool isParentEnabled(String parentName) {
    final children = TransactionCategory.childrenOf(parentName);
    return children.isNotEmpty &&
        children.any((category) => isEnabled(category.name));
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
    _disabledCategories.clear();
    _groupModes.clear();
    notifyListeners();

    try {
      final storedValue = await _storage.read(key: _storageKey(userId));
      if (storedValue != null && storedValue.isNotEmpty) {
        final decoded = jsonDecode(storedValue);
        if (decoded is Map<String, dynamic>) {
          if (decoded['classifications'] is Map<String, dynamic>) {
            final classifications =
                decoded['classifications'] as Map<String, dynamic>;
            for (final category in [
              ...TransactionCategory.all,
              ...TransactionCategory.legacy,
            ]) {
              final value = classifications[category.name];
              if (value is bool) {
                _classifications[category.name] = value;
              }
            }
          } else {
            for (final category in [
              ...TransactionCategory.all,
              ...TransactionCategory.legacy,
            ]) {
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

          final disabledCategories = decoded['disabled_categories'];
          if (disabledCategories is List) {
            for (final value in disabledCategories) {
              if (value is String) {
                _disabledCategories.add(value);
              }
            }
          }

          final groupModes = decoded['group_modes'];
          if (groupModes is Map<String, dynamic>) {
            for (final entry in groupModes.entries) {
              for (final mode in CategoryMode.values) {
                if (mode.name == entry.value) {
                  _groupModes[entry.key] = mode;
                  break;
                }
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

  Future<void> setEnabled(String categoryName, {required bool enabled}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before changing category settings.');
    }

    final wasDisabled = _disabledCategories.contains(categoryName);
    if (enabled) {
      _disabledCategories.remove(categoryName);
    } else {
      _disabledCategories.add(categoryName);
    }
    notifyListeners();

    try {
      await _storage.write(
        key: _storageKey(userId),
        value: jsonEncode(_persistedState),
      );
    } catch (_) {
      if (wasDisabled) {
        _disabledCategories.add(categoryName);
      } else {
        _disabledCategories.remove(categoryName);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setParentEnabled(
    String parentName, {
    required bool enabled,
  }) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before changing category settings.');
    }

    final children = TransactionCategory.childrenOf(parentName);
    final previousDisabledCategories = Set<String>.of(_disabledCategories);
    for (final category in children) {
      if (enabled) {
        _disabledCategories.remove(category.name);
      } else {
        _disabledCategories.add(category.name);
      }
    }
    notifyListeners();

    try {
      await _storage.write(
        key: _storageKey(userId),
        value: jsonEncode(_persistedState),
      );
    } catch (_) {
      _disabledCategories
        ..clear()
        ..addAll(previousDisabledCategories);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setParentMode(
    String parentName, {
    required CategoryMode mode,
  }) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before changing category settings.');
    }

    final previousMode = _groupModes[parentName];
    _groupModes[parentName] = mode;
    notifyListeners();

    try {
      await _storage.write(
        key: _storageKey(userId),
        value: jsonEncode(_persistedState),
      );
    } catch (_) {
      if (previousMode == null) {
        _groupModes.remove(parentName);
      } else {
        _groupModes[parentName] = previousMode;
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
    'disabled_categories': _disabledCategories.toList(),
    'group_modes': {
      for (final entry in _groupModes.entries) entry.key: entry.value.name,
    },
  };

  String _storageKey(String userId) => 'category_preferences_$userId';
}
