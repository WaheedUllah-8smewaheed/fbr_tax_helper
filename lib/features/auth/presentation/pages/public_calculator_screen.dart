import 'package:fbr_tax_helper/features/tax_calculator/presentation/pages/tax_calculator_screen.dart';
import 'package:flutter/material.dart';

class PublicCalculatorScreen extends StatelessWidget {
  const PublicCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TaxCalculatorScreen(
      onLogin: () => Navigator.of(context).maybePop(),
      appBarTitle: 'Tax Calculator',
      fitToViewport: true,
    );
  }
}
