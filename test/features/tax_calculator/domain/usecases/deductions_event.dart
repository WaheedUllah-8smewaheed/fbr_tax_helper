part of 'deductions_bloc.dart';

abstract class DeductionsEvent extends Equatable {
  const DeductionsEvent();

  @override
  List<Object?> get props => [];
}

class ParseTaxCertificate extends DeductionsEvent {
  final ImageSource? imageSource;
  final bool isPdf;

  const ParseTaxCertificate({this.imageSource, this.isPdf = false});

  @override
  List<Object?> get props => [imageSource, isPdf];
}

class SaveDeductions extends DeductionsEvent {
  final String mobileTax;
  final String electricityTax;
  final String internetTax;
  final String vehicleTax;

  const SaveDeductions({
    required this.mobileTax,
    required this.electricityTax,
    required this.internetTax,
    required this.vehicleTax,
  });

  @override
  List<Object> get props => [
    mobileTax,
    electricityTax,
    internetTax,
    vehicleTax,
  ];
}
