import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PercentageCalculatorPage extends StatefulWidget {
  const PercentageCalculatorPage({super.key});

  @override
  State<PercentageCalculatorPage> createState() =>
      _PercentageCalculatorPageState();
}

class _PercentageCalculatorPageState extends State<PercentageCalculatorPage> {
  final _amountController = TextEditingController();
  final _percentageController = TextEditingController();

  double? _calculatedResult;

  void _calculate() {
    final amountText = _amountController.text.trim();
    final percentageText = _percentageController.text.trim();

    if (amountText.isEmpty || percentageText.isEmpty) {
      setState(() => _calculatedResult = null);
      return;
    }

    final amount = double.tryParse(amountText);
    final percentage = double.tryParse(percentageText);

    if (amount != null && percentage != null) {
      setState(() {
        _calculatedResult = amount * (percentage / 100);
      });
    } else {
      setState(() => _calculatedResult = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculate);
    _percentageController.addListener(_calculate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Percentage Calculator'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Calculate the percentage of an amount quickly.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter total amount',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _percentageController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Percentage (%)',
                  hintText: 'Enter percentage',
                  prefixIcon: const Icon(Icons.percent_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 48),
              if (_calculatedResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F6B57).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF0F6B57).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Percentage Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F6B57),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _calculatedResult!.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F6B57),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_percentageController.text.trim()}% of ${_amountController.text.trim()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
