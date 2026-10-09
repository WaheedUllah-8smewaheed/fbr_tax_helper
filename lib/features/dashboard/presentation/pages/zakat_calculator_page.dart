
import 'package:flutter/material.dart';
import 'package:fbr_tax_helper/core/utils/comma_formatter.dart';


class ZakatCalculatorPage extends StatefulWidget {
  const ZakatCalculatorPage({super.key});

  @override
  State<ZakatCalculatorPage> createState() => _ZakatCalculatorPageState();
}

class _ZakatCalculatorPageState extends State<ZakatCalculatorPage> {
  final _wealthController = TextEditingController();
  final _rateController = TextEditingController();

  bool _isGoldNisab = true;
  double? _calculatedZakat;
  bool _isBelowNisab = false;

  void _calculate() {
    final wealthText = _wealthController.text.trim();
    final rateText = _rateController.text.trim();

    if (wealthText.isEmpty || rateText.isEmpty) {
      setState(() {
        _calculatedZakat = null;
        _isBelowNisab = false;
      });
      return;
    }

    final wealth = double.tryParse(wealthText.replaceAll(',', ''));
    final ratePerTola = double.tryParse(rateText.replaceAll(',', ''));

    if (wealth != null && ratePerTola != null) {
      // Nisab Value (PKR) = Tola Rate (PKR/Tola) x Nisab Tola Count
      // [Gold: x 7.5] ya [Silver: x 52.5]
      final nisabTolaCount = _isGoldNisab ? 7.5 : 52.5;
      final nisabValue = nisabTolaCount * ratePerTola;

      setState(() {
        if (wealth >= nisabValue) {
          _calculatedZakat = wealth * 0.025;
          _isBelowNisab = false;
        } else {
          _calculatedZakat = null;
          _isBelowNisab = true;
        }
      });
    } else {
      setState(() {
        _calculatedZakat = null;
        _isBelowNisab = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    
    
  }

  @override
  void dispose() {
    _wealthController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zakat Calculator'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Calculate zakat based on your total wealth and current tola rates.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _wealthController,
                onChanged: (_) => _calculate(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  CommaTextInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Enter Amount (PKR)',
                  hintText: 'e.g. 500000',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 0, 17, 13).withValues(alpha: 0.08) ,
                ),
              ),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Gold'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Silver'),
                  ),
                ],
                selected: {_isGoldNisab},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isGoldNisab = newSelection.first;
                  });
                  _calculate();
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF168F73); //SELECTED COLOR
                      }
                      return Colors.transparent; // UNSELECTED COLOR
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _rateController,
                onChanged: (_) => _calculate(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  CommaTextInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: _isGoldNisab ? 'Gold Rate per Tola (PKR)' : 'Silver Rate per Tola (PKR)',
                  hintText: _isGoldNisab ? 'e.g. 250000' : 'e.g. 3000',
                  prefixIcon: const Icon(Icons.currency_exchange_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 0, 17, 13).withValues(alpha: 0.08) ,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _calculate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F6B57),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Calculate',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (_calculatedZakat != null || _isBelowNisab) ? const Color.fromARGB(255, 0, 17, 13).withValues(alpha: 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_calculatedZakat != null || _isBelowNisab) ? const Color.fromARGB(255, 0, 17, 13).withValues(alpha: 0.08): Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _calculatedZakat != null 
                          ? 'Zakat Due' 
                          : (_isBelowNisab ? 'Status' : 'Result'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: (_calculatedZakat != null || _isBelowNisab) ? FontWeight.w600 : FontWeight.normal,
                        color: (_calculatedZakat != null || _isBelowNisab) ? const Color(0xFF0F6B57) : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isBelowNisab)
                      const Text(
                        'Amount below Nisab threshold',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 1, 49, 39),
                        ),
                      )
                    else
                      Text(
                        _calculatedZakat != null ? _calculatedZakat!.toStringAsFixed(2) : '—',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _calculatedZakat != null ? const Color(0xFF0F6B57) : Colors.black,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Educational tool only, not a religious ruling. Enter today\'s gold/silver rate yourself — this does not fetch live prices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
