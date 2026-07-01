import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'deductions_bloc.dart';

class DeductionsPage extends StatefulWidget {
  const DeductionsPage({super.key});

  @override
  State<DeductionsPage> createState() => _DeductionsPageState();
}

class _DeductionsPageState extends State<DeductionsPage> {
  // State variables for extracted tax amounts
  final _electricityTaxController = TextEditingController();
  final _internetTaxController = TextEditingController();
  final _vehicleTaxController = TextEditingController();

  // A helper for styling
  static const _headerStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  @override
  void dispose() {
    _electricityTaxController.dispose();
    _internetTaxController.dispose();
    _vehicleTaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        },
        builder: (context, state) {
          // Use a key to force the TextFormField to rebuild with the new value from the state
          final mobileTaxController = TextEditingController(
            text: state.mobileTax,
          );

          return Scaffold(
            appBar: AppBar(title: const Text('Deductions & Adjustments')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                context.read<DeductionsBloc>().add(
                  SaveDeductions(
                    mobileTax: mobileTaxController.text,
                    electricityTax: _electricityTaxController.text,
                    internetTax: _internetTaxController.text,
                    vehicleTax: _vehicleTaxController.text,
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
                  Text('Mobile Balance Tax', style: _headerStyle),
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

                  // Section 235 (Electricity)
                  Text('Electricity Bill Tax', style: _headerStyle),
                  const SizedBox(height: 4),
                  const Text(
                    'For bills over Rs. 25,000',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _electricityTaxController,
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

                  // Section 236(1)(c) (Internet)
                  Text('Internet / PTCL Bill Tax', style: _headerStyle),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _internetTaxController,
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

                  // Section 234 (Motor vehicle tax)
                  Text('Vehicle Token Tax', style: _headerStyle),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _vehicleTaxController,
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
