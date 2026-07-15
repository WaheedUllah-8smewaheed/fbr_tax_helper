import 'dart:convert';

import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CategoryPreferencesService extends ChangeNotifier {
  CategoryPreferencesService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, bool> _classifications = {};

  String? _userId;
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  bool isExpense(String categoryName) {
    return _classifications[categoryName] ??
        TransactionCategory.fromName(categoryName).isExpense;
  }

  Future<void> loadForUser(String userId) async {
    if (_userId == userId) return;

    _userId = userId;
    _isLoading = true;
    _loadError = null;
    _classifications.clear();
    notifyListeners();

    try {
      final storedValue = await _storage.read(key: _storageKey(userId));
      if (storedValue != null && storedValue.isNotEmpty) {
        final decoded = jsonDecode(storedValue);
        if (decoded is Map<String, dynamic>) {
          for (final category in TransactionCategory.all) {
            final value = decoded[category.name];
            if (value is bool) {
              _classifications[category.name] = value;
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
        value: jsonEncode(_classifications),
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

  String _storageKey(String userId) => 'category_preferences_$userId';
}
