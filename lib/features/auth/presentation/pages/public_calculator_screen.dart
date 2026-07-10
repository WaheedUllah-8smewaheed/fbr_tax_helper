import 'package:fbr_tax_helper/features/auth/presentation/pages/login_page.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/screens/tax_calculator_screen.dart';
import 'package:flutter/material.dart';

class PublicCalculatorScreen extends StatelessWidget {
  const PublicCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FilerFlow Calculator',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        actions: [
          // Clear visual upgrade action button
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.cloud_upload, color: Colors.white),
            label: const Text(
              'Sync & Track',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      // We pass null for authService to hide authenticated features
      body: TaxCalculatorScreen(
        authService: null,
        footer: _buildUpsellBanner(context),
      ),
    );
  }

  Widget _buildUpsellBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal),
      ),
      child: Column(
        children: [
          const Text(
            "Want to automatically track expenses?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            "Create a free account to capture bank notifications offline and backup records directly inside your private Google Drive vault.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text("Create Free Account"),
          ),
        ],
      ),
    );
  }
}
