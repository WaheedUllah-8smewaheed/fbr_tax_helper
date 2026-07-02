import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/deduction_values.dart';

part 'deductions_event.dart';
part 'deductions_state.dart';

class DeductionsBloc extends Bloc<DeductionsEvent, DeductionsState> {
  DeductionsBloc() : super(const DeductionsState()) {
    on<SaveDeductions>(_onSaveDeductions);
  }

  void _onSaveDeductions(SaveDeductions event, Emitter<DeductionsState> emit) {
    final values = DeductionValues(
      mobileTax: _parseAmount(event.mobileTax),
      electricityTax: _parseAmount(event.electricityTax),
      internetTax: _parseAmount(event.internetTax),
      vehicleTax: _parseAmount(event.vehicleTax),
    );

    final message =
        'Saved adjustable tax paid: PKR ${values.total.toStringAsFixed(0)}';

    emit(
      state.copyWith(
        status: DeductionsStatus.success,
        values: values,
        message: message,
      ),
    );
  }

  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
  }
}
