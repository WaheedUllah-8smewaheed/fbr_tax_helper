import 'package:fbr_tax_helper/features/transactions/data/datasources/transaction_local_data_source.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';
import 'package:fbr_tax_helper/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl({required this.localDataSource});

  final TransactionLocalDataSource localDataSource;

  @override
  Future<void> addTransaction(Transaction transaction) {
    return localDataSource.addTransaction(transaction);
  }

  @override
  Future<List<Transaction>> getTransactions(String userId) {
    return localDataSource.getTransactions(userId);
  }

  @override
  Future<void> updateTransaction(Transaction transaction) {
    return localDataSource.updateTransaction(transaction);
  }

  @override
  Future<void> deleteTransaction({required int id, required String userId}) {
    return localDataSource.deleteTransaction(id: id, userId: userId);
  }
}
