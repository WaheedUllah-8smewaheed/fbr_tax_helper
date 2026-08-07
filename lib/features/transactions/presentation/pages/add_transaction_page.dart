import 'dart:io';

import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';
import 'package:fbr_tax_helper/features/transactions/services/receipt_scanner_service.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({
    super.key,
    this.transaction,
    this.initialCategory,
    this.initialIsExpense,
    this.initialTitle,
    this.initialBeneficiary,
    this.initialPurpose,
    this.initialAmount,
    this.initialDate,
    this.parentCategory,
    this.categoryOptions = const [],
    this.onViewCategoryHistory,
    this.appBarActions = const [],
  });

  final entity.Transaction? transaction;
  final String? initialCategory;
  final bool? initialIsExpense;
  final String? initialTitle;
  final String? initialBeneficiary;
  final String? initialPurpose;
  final double? initialAmount;
  final DateTime? initialDate;
  final String? parentCategory;
  final List<TransactionCategory> categoryOptions;
  final ValueChanged<String>? onViewCategoryHistory;
  final List<Widget> appBarActions;

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
  final _categoryPreferences = CategoryPreferencesService();
  final _receiptScanner = ReceiptScannerService();

  bool _isScanningReceipt = false;
  bool _isLoadingCategoryPreferences = true;
  bool _didLoadCategoryPreferences = false;
  bool _isExpense = true;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _expandedCategory;
  String? _receiptImagePath;
  bool _showCategoryError = false;

  bool get _hasCategoryOptions => widget.categoryOptions.isNotEmpty;

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
      _receiptImagePath = transaction.receiptImagePath;
    } else {
      _titleController.text =
          widget.initialTitle ?? widget.initialCategory ?? '';
      _beneficiaryController.text = widget.initialBeneficiary ?? '';
      _purposeController.text = widget.initialPurpose ?? '';
      if (widget.initialAmount != null) {
        _amountController.text = _formatAmountInput(widget.initialAmount!);
      }
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedCategory = _hasCategoryOptions
          ? widget.initialCategory
          : widget.initialCategory ?? TransactionCategory.misc.name;
      _isExpense =
          widget.initialIsExpense ??
          (_selectedCategory == null
              ? true
              : TransactionCategory.fromName(_selectedCategory!).isExpense);
    }
    if (_hasCategoryOptions) {
      _expandedCategory = _selectedCategory;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadCategoryPreferences) return;
    _didLoadCategoryPreferences = true;
    _loadCategoryPreferences();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _beneficiaryController.dispose();
    _purposeController.dispose();
    _amountController.dispose();
    _categoryPreferences.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryPreferences() async {
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      await _categoryPreferences.loadForUser(userId);
    }
    if (!mounted) return;
    setState(() {
      _isLoadingCategoryPreferences = false;
      _applySelectedCategoryMode();
    });
  }

  void _applySelectedCategoryMode() {
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) return;
    if (_categoryPreferences.isDualMode(selectedCategory)) return;

    _isExpense =
        widget.initialIsExpense ??
        _categoryPreferences.isExpense(selectedCategory);
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
          if (_hasCategoryOptions) {
            _purposeController.text = merchant;
          } else {
            _titleController.text = merchant;
          }
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
    if (_selectedCategory == null) {
      setState(() => _showCategoryError = true);
      return;
    }
    if (!_formKey.currentState!.validate()) {
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
      title: _hasCategoryOptions
          ? _selectedCategory!
          : _titleController.text.trim(),
      beneficiary: _beneficiaryController.text.trim(),
      purpose: _purposeController.text.trim(),
      amount: double.parse(_amountController.text.trim().replaceAll(',', '')),
      isExpense: _categoryPreferences.resolveTransactionTypeForCategory(
        categoryName: _selectedCategory!,
        transactionIsExpense: _isExpense,
      ),
      date: _selectedDate,
      category: _selectedCategory!,
      receiptImagePath: _receiptImagePath,
    );

    context.read<TransactionBloc>().add(
      widget.isEditing
          ? UpdateTransaction(transaction)
          : AddTransaction(transaction),
    );
    Navigator.of(context).pop(true);
  }

  void _openCategoryHistory() {
    final category = _selectedCategory;
    if (category == null) return;
    widget.onViewCategoryHistory?.call(category);
  }

  @override
  Widget build(BuildContext context) {
    final canSelectTransactionType =
        !_isLoadingCategoryPreferences &&
        _selectedCategory != null &&
        _categoryPreferences.isDualMode(_selectedCategory!);

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.parentCategory ??
                _selectedCategory ??
                widget.transaction?.category ??
                'Transaction',
          ),
        ),
        actions: widget.appBarActions,
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
              const SizedBox(height: 15),
              // Form for transaction details
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasCategoryOptions) ...[
                      Text(
                        'Choose a subcategory',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<String>(
                        groupValue: _selectedCategory,
                        onChanged: (value) {
                          if (value != null) _toggleCategory(value);
                        },
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < widget.categoryOptions.length;
                              index++
                            )
                              _ColorfulCategoryRadio(
                                category: widget.categoryOptions[index],
                                index: index,
                                selected:
                                    _selectedCategory ==
                                    widget.categoryOptions[index].name,
                                onTap: () => _toggleCategory(
                                  widget.categoryOptions[index].name,
                                ),
                                details:
                                    _selectedCategory ==
                                            widget
                                                .categoryOptions[index]
                                                .name &&
                                        _expandedCategory ==
                                            widget.categoryOptions[index].name
                                    ? _buildTransactionDetailsFields(
                                        embedded: true,
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                      if (_showCategoryError)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 2),
                          child: Text(
                            'Select a subcategory.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ] else ...[
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
                      _buildTransactionDetailsFields(),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _selectedDate.toLocal().toString().split(' ')[0],
                      ),
                    ),
                    if (canSelectTransactionType) ...[
                      const SizedBox(height: 16),
                      SegmentedButton<bool>(
                        expandedInsets: EdgeInsets.zero,
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Income'),
                            icon: Icon(Icons.arrow_upward),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Expense'),
                            icon: Icon(Icons.arrow_downward),
                          ),
                        ],
                        selected: {_isExpense},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _isExpense = selection.first;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _submitData,
                      icon: Icon(widget.isEditing ? Icons.save : Icons.add),
                      label: Text(
                        widget.isEditing
                            ? 'Save Transaction'
                            : 'Add Transaction',
                      ),
                    ),
                    const SizedBox(height: 5),
                    OutlinedButton.icon(
                      onPressed:
                          _selectedCategory != null &&
                              widget.onViewCategoryHistory != null
                          ? _openCategoryHistory
                          : null,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('View category history'),
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

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _expandedCategory = category;
      _titleController.text = category;
      _showCategoryError = false;
      if (!_categoryPreferences.isDualMode(category)) {
        _isExpense = _categoryPreferences.isExpense(category);
      }
    });
  }

  void _toggleCategory(String category) {
    if (_selectedCategory != category) {
      _selectCategory(category);
      return;
    }

    setState(() {
      _expandedCategory = _expandedCategory == category ? null : category;
    });
  }

  Widget _buildTransactionDetailsFields({bool embedded = false}) {
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _purposeController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: 'PKR ',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      ],
    );

    if (!embedded) return fields;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: fields,
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

class _ColorfulCategoryRadio extends StatelessWidget {
  const _ColorfulCategoryRadio({
    required this.category,
    required this.index,
    required this.selected,
    required this.onTap,
    this.details,
  });

  final TransactionCategory category;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final Widget? details;

  static const _colors = <Color>[
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFFEF6C00),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFF43A047),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return Card(
      margin: const EdgeInsets.only(bottom: 5),
      elevation: selected ? 2 : 0,
      color: color.withValues(alpha: selected ? 0.18 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withValues(alpha: selected ? 0.9 : 0.3),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            dense: true,
            visualDensity: const VisualDensity(vertical: -3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            minTileHeight: 42,
            leading: IgnorePointer(
              child: Radio<String>(
                value: category.name,
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
              ),
            ),
            title: Text(
              category.name,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            trailing: Icon(
              category.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 20,
            ),
          ),
          ?details,
        ],
      ),
    );
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

  /// Returns a widget that displays the receipt image (if available) and provides buttons to scan or remove the
  @override
  // scan the receipt. If an image is available, it will be displayed above the buttons.
 @override
Widget build(BuildContext context) {
  final file = imagePath == null ? null : File(imagePath!);
  final hasImage = file?.existsSync() ?? false;
  final theme = Theme.of(context);

  return Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.teal.shade100),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Receipt image',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.teal.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Take a photo or upload an image. Text will be read on-device and placed into the editable fields below.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file!,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal.shade50,
                    foregroundColor: Colors.teal.shade800,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isScanning ? null : onScan,
                  icon: isScanning
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.teal.shade800,
                          ),
                        )
                      : const Icon(Icons.document_scanner_outlined, size: 18),
                  label: Text(
                    hasImage ? 'Replace & scan' : 'Add & scan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: isScanning ? null : onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
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