part of 'transaction_bloc.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object> get props => [];
}

class LoadTransactions extends TransactionEvent {
  const LoadTransactions();
}

class AddTransaction extends TransactionEvent {
  const AddTransaction(this.transaction);

  final Transaction transaction;

  @override
  List<Object> get props => [transaction];
}

class UpdateTransaction extends TransactionEvent {
  const UpdateTransaction(this.transaction);

  final Transaction transaction;

  @override
  List<Object> get props => [transaction];
}

class DeleteTransaction extends TransactionEvent {
  const DeleteTransaction(this.id);

  final int id;

  @override
  List<Object> get props => [id];
}
