import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fbr_tax_helper/features/deductions/presentation/bloc/deductions_bloc.dart';

class DeductionsPage extends StatelessWidget {
  const DeductionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mobileTaxController = TextEditingController();
    final electricityTaxController = TextEditingController();
    final internetTaxController = TextEditingController();
    final vehicleTaxController = TextEditingController();

    const headerStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    return BlocProvider(
      create: (context) => DeductionsBloc(),
      child: BlocConsumer<DeductionsBloc, DeductionsState>(
        listener: (context, state) {
          if (state.status == DeductionsStatus.success ||
              state.status == DeductionsStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state.status == DeductionsStatus.parsing) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Parsing document...')),
              );
          }

          if (state.status == DeductionsStatus.success) {
            mobileTaxController.text = state.mobileTax;
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Deductions & Adjustments')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                context.read<DeductionsBloc>().add(
                      SaveDeductions(
                        mobileTax: mobileTaxController.text,
                        electricityTax: electricityTaxController.text,
                        internetTax: internetTaxController.text,
                        vehicleTax: vehicleTaxController.text,
                      ),
                    );
              },
              label: const Text('Save Deductions'),
              icon: const Icon(Icons.save),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mobile Balance Tax', style: headerStyle),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: mobileTaxController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'PKR',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: state.status == DeductionsStatus.parsing
                            ? null
                            : () => context.read<DeductionsBloc>().add(
                                  ParseTaxCertificate(
                                    imageSource: ImageSource.camera,
                                  ),
                                ),
                        child: const Text('Scan'),
                      ),
                      ElevatedButton(
                        onPressed: state.status == DeductionsStatus.parsing
                            ? null
                            : () => context.read<DeductionsBloc>().add(
                                  ParseTaxCertificate(
                                    imageSource: ImageSource.gallery,
                                  ),
                                ),
                        child: const Text('Upload'),
                      ),
                      ElevatedButton(
                        onPressed: state.status == DeductionsStatus.parsing
                            ? null
                            : () => context.read<DeductionsBloc>().add(
                                  const ParseTaxCertificate(isPdf: true),
                                ),
                        child: const Text('PDF'),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('Electricity Bill Tax', style: headerStyle),
                  const SizedBox(height: 4),
                  const Text(
                    'For bills over Rs. 25,000',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: electricityTaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter total tax paid',
                      border: OutlineInputBorder(),
                      suffixText: 'PKR',
                    ),
                  ),
                  const Divider(height: 32),
                  const Text('Internet / PTCL Bill Tax', style: headerStyle),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: internetTaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter total tax paid',
                      border: OutlineInputBorder(),
                      suffixText: 'PKR',
                    ),
                  ),
                  const Divider(height: 32),
                  const Text('Vehicle Token Tax', style: headerStyle),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: vehicleTaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter withholding tax paid',
                      border: OutlineInputBorder(),
                      suffixText: 'PKR',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
