part of 'deductions_bloc.dart';

enum DeductionsStatus { initial, loading, success, failure, parsing, parsed }

class DeductionsState extends Equatable {
  final DeductionsStatus status;
  final String mobileTax;
  final String message;

  const DeductionsState({
    this.status = DeductionsStatus.initial,
    this.mobileTax = "0",
    this.message = '',
  });

  DeductionsState copyWith({
    DeductionsStatus? status,
    String? mobileTax,
    String? message,
  }) {
    return DeductionsState(
      status: status ?? this.status,
      mobileTax: mobileTax ?? this.mobileTax,
      message: message ?? this.message,
    );
  }

  @override
  List<Object> get props => [status, mobileTax, message];
}
