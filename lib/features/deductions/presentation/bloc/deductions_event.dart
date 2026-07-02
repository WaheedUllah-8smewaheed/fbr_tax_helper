part of 'deductions_bloc.dart';

abstract class DeductionsEvent extends Equatable {
  const DeductionsEvent();

  @override
  List<Object> get props => [];
}

class SaveDeductions extends DeductionsEvent {
  const SaveDeductions({
    required this.mobileTax,
    required this.electricityTax,
    required this.internetTax,
    required this.vehicleTax,
  });

  final String mobileTax;
  final String electricityTax;
  final String internetTax;
  final String vehicleTax;

  @override
  List<Object> get props => [
    mobileTax,
    electricityTax,
    internetTax,
    vehicleTax,
  ];
}
