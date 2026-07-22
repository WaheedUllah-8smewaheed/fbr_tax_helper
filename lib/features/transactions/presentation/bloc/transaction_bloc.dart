import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart';
import 'package:fbr_tax_helper/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc({
    required TransactionRepository transactionRepository,
    required AuthService authService,
  }) : _transactionRepository = transactionRepository,
       _authService = authService,
       super(TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<AddTransaction>(_onAddTransaction);
    on<UpdateTransaction>(_onUpdateTransaction);
    on<DeleteTransaction>(_onDeleteTransaction);
  }

  final TransactionRepository _transactionRepository;
  final AuthService _authService;

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    try {
      final userId = _currentUserId();
      final transactions = await _transactionRepository.getTransactions(userId);
      emit(TransactionLoaded(userId: userId, transactions: transactions));
    } catch (error) {
      emit(TransactionError(error.toString()));
    }
  }

  Future<void> _onAddTransaction(
    AddTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final userId = _currentUserId();
      await _transactionRepository.addTransaction(
        event.transaction.copyWith(userId: userId),
      );
      final transactions = await _transactionRepository.getTransactions(userId);
      emit(TransactionLoaded(userId: userId, transactions: transactions));
    } catch (error) {
      emit(TransactionError(error.toString()));
    }
  }

  Future<void> _onUpdateTransaction(
    UpdateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final userId = _currentUserId();
      await _transactionRepository.updateTransaction(
        event.transaction.copyWith(userId: userId),
      );
      final transactions = await _transactionRepository.getTransactions(userId);
      emit(TransactionLoaded(userId: userId, transactions: transactions));
    } catch (error) {
      emit(TransactionError(error.toString()));
    }
  }

  Future<void> _onDeleteTransaction(
    DeleteTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final userId = _currentUserId();
      await _transactionRepository.deleteTransaction(
        id: event.id,
        userId: userId,
      );
      final transactions = await _transactionRepository.getTransactions(userId);
      emit(TransactionLoaded(userId: userId, transactions: transactions));
    } catch (error) {
      emit(TransactionError(error.toString()));
    }
  }

  String _currentUserId() {
    final userId = _authService.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw const AuthServiceException('Sign in before managing transactions.');
    }
    return userId;
  }
}
