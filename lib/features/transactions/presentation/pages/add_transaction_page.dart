import 'dart:io';

import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/services/receipt_scanner_service.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key, this.transaction, this.initialCategory});

  final entity.Transaction? transaction;
  final String? initialCategory;

  bool get isEditing => transaction != null;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _beneficiaryController = TextEditingController();
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptScanner = ReceiptScannerService();

  bool _isScanningReceipt = false;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _receiptImagePath;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    if (transaction != null) {
      _titleController.text = transaction.title;
      _beneficiaryController.text = transaction.beneficiary;
      _purposeController.text = transaction.purpose;
      _amountController.text = _formatAmountInput(transaction.amount);
      _selectedDate = transaction.date;
      _selectedCategory = transaction.category;
      _receiptImagePath = transaction.receiptImagePath;
    } else {
      _selectedCategory =
          widget.initialCategory ?? TransactionCategory.misc.name;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _beneficiaryController.dispose();
    _purposeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || picked == _selectedDate || !mounted) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take receipt photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _scanReceipt(source);
  }

  Future<void> _scanReceipt(ImageSource source) async {
    setState(() => _isScanningReceipt = true);
    try {
      final result = await _receiptScanner.captureAndScan(source);
      if (result == null || !mounted) return;
      setState(() {
        _receiptImagePath = result.imagePath;
        final merchant = result.merchant;
        if (merchant != null) {
          _titleController.text = merchant;
          _beneficiaryController.text = merchant;
        }
        if (result.purpose != null) {
          _purposeController.text = result.purpose!;
        }
        if (result.amount != null) {
          _amountController.text = _formatAmountInput(result.amount!);
        }
        if (result.date != null) {
          _selectedDate = result.date!;
        }
        if (widget.initialCategory == null ||
            _selectedCategory == TransactionCategory.misc.name) {
          _selectedCategory = result.suggestedCategory;
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.rawText.trim().isEmpty
                  ? 'Receipt attached, but no text was detected. Enter the details manually.'
                  : 'Receipt scanned. Review and change the details before saving.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not scan the receipt: $error')),
        );
    } finally {
      if (mounted) setState(() => _isScanningReceipt = false);
    }
  }

  void _submitData() {
    if (_selectedCategory == null || !_formKey.currentState!.validate()) {
      return;
    }

    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sign in before adding transactions.')),
        );
      return;
    }

    final transaction = entity.Transaction(
      id: widget.transaction?.id,
      userId: userId,
      title: _titleController.text.trim(),
      beneficiary: _beneficiaryController.text.trim(),
      purpose: _purposeController.text.trim(),
      amount: double.parse(_amountController.text.trim().replaceAll(',', '')),
      isExpense: TransactionCategory.fromName(_selectedCategory!).isExpense,
      date: _selectedDate,
      category: _selectedCategory!,
      receiptImagePath: _receiptImagePath,
    );

    context.read<TransactionBloc>().add(
      widget.isEditing
          ? UpdateTransaction(transaction)
          : AddTransaction(transaction),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Transaction' : 'Add Transaction'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReceiptPanel(
                imagePath: _receiptImagePath,
                isScanning: _isScanningReceipt,
                onScan: _chooseReceiptSource,
                onRemove: () => setState(() => _receiptImagePath = null),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: TransactionCategory.all
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.name,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: _requiredValidator('Enter a title.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _beneficiaryController,
                      decoration: const InputDecoration(
                        labelText: 'Beneficiary',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: _requiredValidator('Enter a beneficiary.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _purposeController,
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      validator: _requiredValidator('Enter a purpose.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'PKR ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').trim().replaceAll(',', ''),
                        );
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _selectedDate.toLocal().toString().split(' ')[0],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _submitData,
                      icon: Icon(widget.isEditing ? Icons.save : Icons.add),
                      label: Text(
                        widget.isEditing
                            ? 'Save Transaction'
                            : 'Add Transaction',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  String _formatAmountInput(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }
}

class _ReceiptPanel extends StatelessWidget {
  const _ReceiptPanel({
    required this.imagePath,
    required this.isScanning,
    required this.onScan,
    required this.onRemove,
  });

  final String? imagePath;
  final bool isScanning;
  final VoidCallback onScan;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final file = imagePath == null ? null : File(imagePath!);
    final hasImage = file?.existsSync() ?? false;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.teal.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Receipt image',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Take a photo or upload an image. Text will be read on-device and placed into the editable fields below.',
            ),
            if (hasImage) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file!,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isScanning ? null : onScan,
                    icon: isScanning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.document_scanner_outlined),
                    label: Text(hasImage ? 'Replace & scan' : 'Add & scan'),
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Remove receipt',
                    onPressed: isScanning ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
