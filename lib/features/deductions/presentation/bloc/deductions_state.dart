part of 'deductions_bloc.dart';

enum DeductionsStatus { initial, success, failure }

class DeductionsState extends Equatable {
  const DeductionsState({
    this.status = DeductionsStatus.initial,
    this.values = DeductionValues.zero,
    this.message = '',
  });

  final DeductionsStatus status;
  final DeductionValues values;
  final String message;

  DeductionsState copyWith({
    DeductionsStatus? status,
    DeductionValues? values,
    String? message,
  }) {
    return DeductionsState(
      status: status ?? this.status,
      values: values ?? this.values,
      message: message ?? this.message,
    );
  }

  @override
  List<Object> get props => [status, values, message];
}
