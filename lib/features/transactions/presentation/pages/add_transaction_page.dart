import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({
    super.key,
    this.transaction,
    this.initialCategory,
    this.initialIsExpense,
  });

  final entity.Transaction? transaction;
  final String? initialCategory;
  final bool? initialIsExpense;

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

  bool _isExpense = true;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    if (transaction != null) {
      _titleController.text = transaction.title;
      _beneficiaryController.text = transaction.beneficiary;
      _purposeController.text = transaction.purpose;
      _amountController.text = _formatAmountInput(transaction.amount);
      _isExpense = transaction.isExpense;
      _selectedDate = transaction.date;
      _selectedCategory = transaction.category;
    } else {
      _isExpense = widget.initialIsExpense ?? true;
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
      isExpense: _isExpense,
      date: _selectedDate,
      category: _selectedCategory!,
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
    final theme = Theme.of(context);

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
              if (_selectedCategory != null) ...[
                Text(
                  'Category: $_selectedCategory',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
