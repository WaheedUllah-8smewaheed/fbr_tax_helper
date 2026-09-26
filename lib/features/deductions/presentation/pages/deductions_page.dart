import 'package:fbr_tax_helper/features/deductions/domain/entities/deduction_values.dart';
import 'package:fbr_tax_helper/features/deductions/presentation/bloc/deductions_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeductionsPage extends StatefulWidget {
  const DeductionsPage({super.key, this.initialValues = DeductionValues.zero});

  final DeductionValues initialValues;

  @override
  State<DeductionsPage> createState() => _DeductionsPageState();
}

class _DeductionsPageState extends State<DeductionsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mobileTaxController;
  late final TextEditingController _electricityTaxController;
  late final TextEditingController _internetTaxController;
  late final TextEditingController _vehicleTaxController;

  @override
  void initState() {
    super.initState();
    _mobileTaxController = TextEditingController(
      text: _formatInputAmount(
        widget.initialValues.mobileTax,
        defaultText: '0',
      ),
    );
    _electricityTaxController = TextEditingController(
      text: _formatInputAmount(widget.initialValues.electricityTax),
    );
    _internetTaxController = TextEditingController(
      text: _formatInputAmount(widget.initialValues.internetTax),
    );
    _vehicleTaxController = TextEditingController(
      text: _formatInputAmount(widget.initialValues.vehicleTax),
    );
  }

  @override
  void dispose() {
    _mobileTaxController.dispose();
    _electricityTaxController.dispose();
    _internetTaxController.dispose();
    _vehicleTaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    return BlocProvider(
      create: (context) => DeductionsBloc(),
      child: BlocConsumer<DeductionsBloc, DeductionsState>(
        listener: (context, state) {
          if (state.status == DeductionsStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
            return;
          }

          if (state.status == DeductionsStatus.success) {
            Navigator.of(context).pop(state.values);
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Deductions & Adjustments')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;

                context.read<DeductionsBloc>().add(
                  SaveDeductions(
                    mobileTax: _mobileTaxController.text,
                    electricityTax: _electricityTaxController.text,
                    internetTax: _internetTaxController.text,
                    vehicleTax: _vehicleTaxController.text,
                  ),
                );
              },
              label: const Text('Apply Deductions'),
              icon: const Icon(Icons.save_outlined),
            ),
            body: SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mobile Balance Tax', style: headerStyle),
                      const SizedBox(height: 4),
                      const Text(
                        'Required annual adjustable tax. Enter 0 if none.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      _MoneyField(
                        controller: _mobileTaxController,
                        labelText: 'Mobile tax paid',
                        validator: _validateRequiredAmount,
                      ),
                      const Divider(height: 32),
                      const Text('Electricity Bill Tax', style: headerStyle),
                      const SizedBox(height: 4),
                      const Text(
                        'Use the total annual withholding shown on bills.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      _MoneyField(
                        controller: _electricityTaxController,
                        labelText: 'Electricity tax paid',
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Internet / PTCL Bill Tax',
                        style: headerStyle,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter annual adjustable tax from internet bills.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      _MoneyField(
                        controller: _internetTaxController,
                        labelText: 'Internet tax paid',
                      ),
                      const Divider(height: 32),
                      const Text('Vehicle Token Tax', style: headerStyle),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter token or registration withholding tax paid.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      _MoneyField(
                        controller: _vehicleTaxController,
                        labelText: 'Vehicle tax paid',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _validateRequiredAmount(String? value) {
    final trimmed = value?.replaceAll(',', '').trim() ?? '';
    if (trimmed.isEmpty) return 'Enter mobile tax paid, or 0 if none';
    final amount = double.tryParse(trimmed);
    if (amount == null || amount < 0) return 'Enter a valid amount';
    return null;
  }

  String _formatInputAmount(double value, {String defaultText = ''}) {
    if (value == 0) return defaultText;
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.labelText,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      validator: validator ?? _validateOptionalAmount,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixText: 'PKR',
      ),
    );
  }

  String? _validateOptionalAmount(String? value) {
    final trimmed = value?.replaceAll(',', '').trim() ?? '';
    if (trimmed.isEmpty) return null;
    final amount = double.tryParse(trimmed);
    if (amount == null || amount < 0) return 'Enter a valid amount';
    return null;
  }
}
