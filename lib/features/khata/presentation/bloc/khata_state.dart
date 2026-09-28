part of 'khata_bloc.dart';

abstract class KhataState extends Equatable {
  const KhataState();

  @override
  List<Object> get props => [];
}

class KhataInitial extends KhataState {}

class KhataLoading extends KhataState {}

class KhataLoaded extends KhataState {
  final List<KhataEntry> entries;
  const KhataLoaded({required this.entries});
  @override
  List<Object> get props => [entries];
}

class KhataError extends KhataState {
  final String message;
  const KhataError({required this.message});
  @override
  List<Object> get props => [message];
}
