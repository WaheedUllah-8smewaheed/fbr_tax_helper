import 'package:fbr_tax_helper/features/tax_calculator/presentation/pages/tax_calculator_screen.dart';
import 'package:flutter/material.dart';

class PublicCalculatorScreen extends StatelessWidget {
  const PublicCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TaxCalculatorScreen(
      onLogin: () => Navigator.of(context).maybePop(),
      footer: _buildUpsellBanner(context),
    );
  }

  Widget _buildUpsellBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          const Text(
            "Want to automatically track expenses?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            "Create a free account to save transactions and back up records directly inside your private Google Drive vault.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text("Create Free Account"),
          ),
        ],
      ),
    );
  }
}
