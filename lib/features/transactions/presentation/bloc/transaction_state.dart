part of 'transaction_bloc.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  const TransactionLoaded({required this.userId, required this.transactions});

  final String userId;
  final List<Transaction> transactions;

  @override
  List<Object> get props => [userId, transactions];
}

class TransactionError extends TransactionState {
  const TransactionError(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}
