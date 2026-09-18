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
  final Map<String, List<String>> _customSubcategories = {};
  final Set<String> _removedCategories = <String>{};

  String? _userId;
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  bool isCustomCategory(String categoryName) {
    for (final list in _customSubcategories.values) {
      if (list.contains(categoryName)) return true;
    }
    return false;
  }

  String? parentNameFor(String categoryName) {
    for (final entry in _customSubcategories.entries) {
      if (entry.value.contains(categoryName)) {
        return entry.key;
      }
    }
    return TransactionCategory.parentNameFor(categoryName);
  }

  bool isParentCategory(String name) {
    if (_customSubcategories.containsKey(name)) return true;
    for (final superEntry in TransactionCategory.hierarchy.values) {
      if (superEntry.containsKey(name)) return true;
    }
    return false;
  }

  List<TransactionCategory> childrenOf(String parentName) {
    final defaultChildren = TransactionCategory.childrenOf(parentName);
    final customNames = _customSubcategories[parentName] ?? const [];
    final parentMode = modeForParent(parentName);

    final list = <TransactionCategory>[];
    for (final cat in defaultChildren) {
      if (!_removedCategories.contains(cat.name)) {
        list.add(cat);
      }
    }
    for (final name in customNames) {
      if (!_removedCategories.contains(name) &&
          !list.any((c) => c.name == name)) {
        final isExp = parentMode == CategoryMode.both
            ? (_classifications[name] ?? false)
            : (parentMode == CategoryMode.expense);
        list.add(TransactionCategory(name: name, isExpense: isExp));
      }
    }
    return list;
  }

  Map<String, Map<String, List<TransactionCategory>>> get hierarchy {
    final result = <String, Map<String, List<TransactionCategory>>>{};
    for (final superEntry in TransactionCategory.hierarchy.entries) {
      final parentMap = <String, List<TransactionCategory>>{};
      for (final parentEntry in superEntry.value.entries) {
        parentMap[parentEntry.key] = childrenOf(parentEntry.key);
      }
      result[superEntry.key] = parentMap;
    }
    return result;
  }

  bool isExpense(String categoryName) {
    if (isParentCategory(categoryName)) {
      return modeForParent(categoryName) == CategoryMode.expense;
    }
    final groupMode = _modeForCategory(categoryName);
    if (groupMode == CategoryMode.income) return false;
    if (groupMode == CategoryMode.expense) return true;
    if (_classifications.containsKey(categoryName)) {
      return _classifications[categoryName]!;
    }
    return TransactionCategory.fromName(categoryName).isExpense;
  }

  bool isDualMode(String categoryName) {
    final groupMode = _modeForCategory(categoryName);
    if (groupMode != null) return groupMode == CategoryMode.both;
    return _dualModeCategories.contains(categoryName);
  }

  CategoryMode? _modeForCategory(String categoryName) {
    final parentName = parentNameFor(categoryName);
    return parentName == null ? null : modeForParent(parentName);
  }

  CategoryMode modeForParent(String parentName) {
    final storedMode = _groupModes[parentName];
    if (storedMode != null) return storedMode;
    final defaultChildren = TransactionCategory.childrenOf(parentName);
    final hasIncome = defaultChildren.any((category) => !category.isExpense);
    final hasExpense = defaultChildren.any((category) => category.isExpense);
    if (hasIncome && hasExpense) return CategoryMode.both;
    return hasExpense ? CategoryMode.expense : CategoryMode.income;
  }

  bool isEnabled(String categoryName) {
    return !_disabledCategories.contains(categoryName);
  }

  bool isParentEnabled(String parentName) {
    final children = childrenOf(parentName);
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
    _customSubcategories.clear();
    _removedCategories.clear();
    notifyListeners();

    try {
      final storedValue = await _storage.read(key: _storageKey(userId));
      if (storedValue != null && storedValue.isNotEmpty) {
        final decoded = jsonDecode(storedValue);
        if (decoded is Map<String, dynamic>) {
          if (decoded['classifications'] is Map<String, dynamic>) {
            final classifications =
                decoded['classifications'] as Map<String, dynamic>;
            for (final entry in classifications.entries) {
              if (entry.value is bool) {
                _classifications[entry.key] = entry.value as bool;
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

          final removedCategories = decoded['removed_categories'];
          if (removedCategories is List) {
            for (final value in removedCategories) {
              if (value is String) {
                _removedCategories.add(value);
              }
            }
          }

          final customSubcategories = decoded['custom_subcategories'];
          if (customSubcategories is Map<String, dynamic>) {
            for (final entry in customSubcategories.entries) {
              if (entry.value is List) {
                _customSubcategories[entry.key] = (entry.value as List)
                    .whereType<String>()
                    .toList();
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

          // Heal existing classifications for custom subcategories under single-mode parents
          for (final entry in _customSubcategories.entries) {
            final parent = entry.key;
            final parentMode = modeForParent(parent);
            if (parentMode != CategoryMode.both) {
              final shouldBeExpense = parentMode == CategoryMode.expense;
              for (final child in entry.value) {
                _classifications[child] = shouldBeExpense;
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

  Future<void> addSubcategory({
    required String parentName,
    required String categoryName,
    bool? isExpense,
  }) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before changing category settings.');
    }

    final trimmedParent = parentName.trim();
    final trimmedName = categoryName.trim();
    if (trimmedParent.isEmpty || trimmedName.isEmpty) {
      throw ArgumentError('Category name and parent category cannot be empty.');
    }

    final existingList = _customSubcategories[trimmedParent] ?? <String>[];
    final wasRemoved = _removedCategories.contains(trimmedName);
    final wasCustom = existingList.contains(trimmedName);

    _removedCategories.remove(trimmedName);
    _disabledCategories.remove(trimmedName);
    if (!wasCustom) {
      _customSubcategories[trimmedParent] = [...existingList, trimmedName];
    }
    final parentMode = modeForParent(trimmedParent);
    final effectiveIsExpense = parentMode == CategoryMode.both
        ? (isExpense ?? false)
        : (parentMode == CategoryMode.expense);
    _classifications[trimmedName] = effectiveIsExpense;
    notifyListeners();

    try {
      await _storage.write(
        key: _storageKey(userId),
        value: jsonEncode(_persistedState),
      );
    } catch (_) {
      if (wasRemoved) {
        _removedCategories.add(trimmedName);
      }
      if (!wasCustom) {
        _customSubcategories[trimmedParent] = existingList;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeSubcategory({
    required String parentName,
    required String categoryName,
  }) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before changing category settings.');
    }

    final trimmedParent = parentName.trim();
    final trimmedName = categoryName.trim();

    final prevCustomList = _customSubcategories[trimmedParent] != null
        ? List<String>.from(_customSubcategories[trimmedParent]!)
        : null;
    final wasRemoved = _removedCategories.contains(trimmedName);

    if (_customSubcategories[trimmedParent] != null) {
      _customSubcategories[trimmedParent]!.remove(trimmedName);
    }

    final isDefaultChild = TransactionCategory.childrenOf(trimmedParent)
        .any((cat) => cat.name == trimmedName);
    if (isDefaultChild) {
      _removedCategories.add(trimmedName);
    }

    _disabledCategories.remove(trimmedName);
    _classifications.remove(trimmedName);
    _dualModeCategories.remove(trimmedName);
    notifyListeners();

    try {
      await _storage.write(
        key: _storageKey(userId),
        value: jsonEncode(_persistedState),
      );
    } catch (_) {
      if (prevCustomList != null) {
        _customSubcategories[trimmedParent] = prevCustomList;
      }
      if (!wasRemoved) {
        _removedCategories.remove(trimmedName);
      }
      notifyListeners();
      rethrow;
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

    final children = childrenOf(parentName);
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
    'removed_categories': _removedCategories.toList(),
    'custom_subcategories': {
      for (final entry in _customSubcategories.entries) entry.key: entry.value,
    },
    'group_modes': {
      for (final entry in _groupModes.entries) entry.key: entry.value.name,
    },
  };

  String _storageKey(String userId) => 'category_preferences_$userId';
}
