part of '../../../dashboard/presentation/pages/dashboard_screen.dart';

enum KhataSegmentFilter { payable, receivable }

class _KhataPage extends StatefulWidget {
  const _KhataPage({super.key, required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<_KhataPage> createState() => _KhataPageState();
}

class _KhataPageState extends State<_KhataPage> {
  KhataSegmentFilter _selectedFilter = KhataSegmentFilter.payable;
  List<KhataEntry> _entries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  CategoryPreferencesService get _categoryPreferences =>
      widget.categoryPreferences;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthService>().currentUser?.uid;
      final rows = await TaxDatabase.instance
          .fetchKhataEntries(userId: userId)
          .timeout(const Duration(seconds: 2));
      final list = rows.map((r) => KhataEntry.fromMap(r)).toList();
      if (mounted) {
        setState(() {
          _entries = list;
        });
      }
    } catch (_) {
      // Gracefully handle in widget tests / unsupported platforms
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'Rs ${formatter.format(amount)}';
  }

  double get _totalPayable => _entries
      .where((e) => e.isPayable && !e.isPaid && !e.isWrittenOff)
      .fold(0.0, (sum, e) => sum + e.remainingAmount);

  double get _totalReceivable => _entries
      .where((e) => !e.isPayable && !e.isPaid && !e.isWrittenOff)
      .fold(0.0, (sum, e) => sum + e.remainingAmount);

  double get _netBalance => _totalReceivable - _totalPayable;

  List<KhataEntry> get _filteredEntries {
    return _entries.where((entry) {
      if (entry.isPaid || entry.isWrittenOff) return false;
      final matchesFilter = switch (_selectedFilter) {
        KhataSegmentFilter.payable => entry.isPayable,
        KhataSegmentFilter.receivable => !entry.isPayable,
      };
      if (!matchesFilter) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return entry.title.toLowerCase().contains(q) ||
          entry.party.toLowerCase().contains(q) ||
          entry.description.toLowerCase().contains(q) ||
          entry.amount.toString().contains(q) ||
          entry.amount.toStringAsFixed(2).contains(q) ||
          (entry.isPayable ? 'payable' : 'receivable').contains(q);
    }).toList();
  }

  Widget _buildSegmentTab(
    String title,
    String subtitle,
    KhataSegmentFilter filter,
  ) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F6B57) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F6B57).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E3A2F),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : Colors.black54,
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddOrEditEntryDialog({
    KhataEntry? existingEntry,
    bool? isPayableDefault,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final isEditing = existingEntry != null;
    final bool isPayable =
        existingEntry?.isPayable ??
        (isPayableDefault ?? (_selectedFilter == KhataSegmentFilter.payable));
    final titleController = TextEditingController(
      text: existingEntry?.title ?? '',
    );
    final amountController = TextEditingController(
      text: existingEntry != null
          ? existingEntry.amount.toStringAsFixed(2)
          : '',
    );
    final partyController = TextEditingController(
      text: existingEntry?.party ?? '',
    );
    bool fromIncome = existingEntry?.fromIncome ?? false;
    final formKey = GlobalKey<FormState>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (bottomSheetContext) => Scaffold(
          appBar: AppBar(
            title: Text(
              isEditing
                  ? (isPayable ? 'Edit Payable' : 'Edit Receivable')
                  : (isPayable ? 'Add Payable' : 'Add Receivable'),
            ),
          ),
          body: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (builderContext, setModalState) {
                final mediaQuery = MediaQuery.of(builderContext);
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: EdgeInsets.only(
                    bottom:
                        mediaQuery.viewInsets.bottom +
                        mediaQuery.padding.bottom +
                        20,
                    top: 20,
                    left: 20,
                    right: 20,
                  ),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isEditing
                                ? (isPayable
                                      ? 'Edit Payable'
                                      : 'Edit Receivable')
                                : (isPayable
                                      ? 'New Payable'
                                      : 'New Receivable'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A2F),
                            ),
                          ),
                          Text(
                            isPayable
                                ? 'Record a payable'
                                : 'Record a receivable',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: titleController,
                            decoration: InputDecoration(
                              hintText: 'Title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: partyController,
                            decoration: InputDecoration(
                              labelText: isPayable
                                  ? 'To (Supplier / Vendor / Person) *'
                                  : 'From (Customer / Client / Debtor) *',
                              hintText: isPayable ? 'To' : 'From',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return isPayable
                                    ? 'Please specify who to pay'
                                    : 'Please specify who owes you';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Amount',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an amount';
                              }
                              final parsed = double.tryParse(value.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a valid positive number';
                              }
                              if (existingEntry != null &&
                                  parsed < existingEntry.settledAmount) {
                                return 'Amount cannot be less than already settled (Rs ${existingEntry.settledAmount.toStringAsFixed(0)})';
                              }
                              return null;
                            },
                          ),
                          if (!isPayable)
                            CheckboxListTile(
                              title: const Text('From Income'),
                              subtitle: const Text('Minimize this amount from total income'),
                              value: fromIncome,
                              onChanged: (val) {
                                setModalState(() {
                                  fromIncome = val ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.primary,
                            ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pop(bottomSheetContext),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final user = context
                                        .read<AuthService>()
                                        .currentUser;
                                    final userId = user?.uid ?? '';
                                    final amount = double.parse(
                                      amountController.text.trim(),
                                    );

                                    final entryToSave = KhataEntry(
                                      id: existingEntry?.id,
                                      userId: userId,
                                      title: titleController.text.trim(),
                                      party: partyController.text.trim(),
                                      amount: amount,
                                      isPayable: isPayable,
                                      date:
                                          existingEntry?.date ?? DateTime.now(),
                                      dueDate: existingEntry?.dueDate,
                                      description:
                                          existingEntry?.description ?? '',
                                      isPaid: existingEntry != null
                                          ? (existingEntry.settledAmount >=
                                                amount)
                                          : false,
                                      settledAmount:
                                          existingEntry?.settledAmount ?? 0.0,
                                      isWrittenOff:
                                          existingEntry?.isWrittenOff ?? false,
                                      fromIncome: fromIncome,
                                    );

                                    if (isEditing) {
                                      await TaxDatabase.instance
                                          .updateKhataEntry(
                                            entryToSave.toMap(),
                                          );
                                    } else {
                                      final newKhataId = await TaxDatabase.instance
                                          .insertKhataEntry(
                                            entryToSave.toMap(),
                                          );
                                      if (!isPayable && fromIncome) {
                                         await TaxDatabase.instance.insertTransaction({
                                            'userId': userId,
                                            'title': 'Receivable: ${entryToSave.title}',
                                            'beneficiary': entryToSave.party,
                                            'purpose': 'Khata Loan (From Income)',
                                            'amount': amount,
                                            'isExpense': 1,
                                            'date': entryToSave.date.toIso8601String(),
                                            'category': 'Khata',
                                            'khataEntryId': newKhataId,
                                         });
                                         if (bottomSheetContext.mounted) {
                                           bottomSheetContext.read<TransactionBloc>().add(LoadTransactions());
                                         }
                                      }
                                    }

                                    if (bottomSheetContext.mounted) {
                                      Navigator.pop(bottomSheetContext);
                                    }
                                    _loadEntries();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isEditing
                                                ? (isPayable
                                                      ? 'Payable updated'
                                                      : 'Receivable updated')
                                                : (isPayable
                                                      ? 'Payable added'
                                                      : 'Receivable added'),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F6B57),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    isEditing
                                        ? 'Save Changes'
                                        : (isPayable
                                              ? 'Add Payable'
                                              : 'Add Receivable'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettlementDialog(KhataEntry entry) async {
    final remaining = entry.remainingAmount;
    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _TransactionsPage(
          categoryPreferences: _categoryPreferences,
          filter: entry.isPayable
              ? TransactionTypeFilter.expense
              : TransactionTypeFilter.income,
          onFilterChanged: (_) {},
          showAppBar: true,
          showTypeFilter: false,
          onParentCategorySelected: (parentCategory, categoryOptions) async {
            final categorySaved = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => AddTransactionPage(
                  parentCategory: parentCategory,
                  categoryOptions: categoryOptions,
                  categoryPreferences: _categoryPreferences,
                  initialIsExpense: entry.isPayable,
                  initialAmount: remaining,
                  initialPurpose: entry.party,
                  initialDate: DateTime.now(),
                  isSettlement: true,
                  khataEntryId: entry.id,
                  linkedCounterpartyOrAsset: entry.party,
                ),
              ),
            );
            if (categorySaved == true && context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
        ),
      ),
    );
    if (saved != true || !mounted) return;

    final newSettledAmount = entry.amount;
    final isFullySettled = newSettledAmount >= entry.amount - 0.001;

    await TaxDatabase.instance.updateKhataEntry(
      entry
          .copyWith(settledAmount: newSettledAmount, isPaid: isFullySettled)
          .toMap(),
    );

    await _loadEntries();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFullySettled
                ? 'Fully settled! Added to ${entry.isPayable ? "Expenses" : "Income"}.'
                : 'Settlement recorded in ${entry.isPayable ? "Expenses" : "Income"}.',
          ),
          backgroundColor: const Color(0xFF0F6B57),
        ),
      );
    }
  }

  // Future<void> _writeOffEntry(KhataEntry entry) async {
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (dialogContext) {
  //       return AlertDialog(
  //         title: const Text('Write Off Bad Debt?'),
  //         content: Text(
  //           'Write off "${entry.title}" (${_formatAmount(entry.remainingAmount)}) as bad debt? This will close the entry without creating any income or expense transaction.',
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(dialogContext, false),
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () => Navigator.pop(dialogContext, true),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.red.shade700,
  //               foregroundColor: Colors.white,
  //             ),
  //             child: const Text('Write Off'),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   if (confirmed == true && entry.id != null) {
  //     await TaxDatabase.instance.updateKhataEntry(
  //       entry.copyWith(isWrittenOff: true, isPaid: true).toMap(),
  //     );
  //     _loadEntries();
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Entry written off as bad debt')),
  //       );
  //     }
  //   }
  // }

  Future<void> _deleteEntry(KhataEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Khata Entry?'),
          content: Text('Are you sure you want to delete "${entry.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && entry.id != null) {
      await TaxDatabase.instance.deleteKhataEntry(entry.id!);
      _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Khata entry deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 96.0;

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
        children: [
          // Top Overview Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.forest, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Khata',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cream.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Net: ${_formatAmount(_netBalance)}',
                        style: const TextStyle(
                          color: AppColors.warmGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: Color(0xFFFF8A80),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Total Payable',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatAmount(_totalPayable),
                                style: const TextStyle(
                                  color: Color(0xFFFF8A80),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Open balance',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: Color(0xFFB9F6CA),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Total Receivable',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatAmount(_totalReceivable),
                                style: const TextStyle(
                                  color: Color(0xFFB9F6CA),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Open balance',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Segmented Distribution Bar (Payable, Receivable) with plain Urdu/English hints
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE8DCC0), width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildSegmentTab(
                  'Payable',
                  'Payable',
                  KhataSegmentFilter.payable,
                ),
                _buildSegmentTab(
                  'Receivable',
                  'Receivable',
                  KhataSegmentFilter.receivable,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Add Entry Button (+ button for Payable / Receivable)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _openAddOrEditEntryDialog(
                isPayableDefault: _selectedFilter == KhataSegmentFilter.payable,
              ),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: Text(
                _selectedFilter == KhataSegmentFilter.payable
                    ? 'Add Payable'
                    : 'Add Receivable',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search Filter
          if (_entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            ),

          // Content List
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No matching entries found'
                        : _selectedFilter == KhataSegmentFilter.payable
                        ? 'No open payables'
                        : 'No open receivables',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedFilter == KhataSegmentFilter.payable
                        ? 'Tap "Add Payable" above to create a payable.'
                        : 'Tap "Add Receivable" above to create a receivable.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((entry) {
              final isPartiallySettled = entry.settledAmount > 0;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: entry.isPayable
                        ? const Color(0xFFFFCDD2)
                        : const Color(0xFFC8E6C9),
                    width: 1,
                  ),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: entry.isPayable
                                  ? const Color(0xFFFFEBEE)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  entry.isPayable
                                      ? Icons.call_made_rounded
                                      : Icons.call_received_rounded,
                                  size: 14,
                                  color: entry.isPayable
                                      ? const Color(0xFFC62828)
                                      : const Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  entry.isPayable
                                      ? 'Payable (Dena hai)'
                                      : 'Receivable (Lena hai)',
                                  style: TextStyle(
                                    color: entry.isPayable
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(entry.date),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A2F),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      entry.isPayable ? 'To: ' : 'From: ',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.party,
                                        style: const TextStyle(
                                          color: Color(0xFF0F6B57),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (entry.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.description,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (entry.dueDate != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.event_available,
                                        size: 13,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Due: ${DateFormat('dd MMM yyyy').format(entry.dueDate!)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatAmount(entry.remainingAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: entry.isPayable
                                      ? const Color(0xFFC62828)
                                      : const Color(0xFF2E7D32),
                                ),
                              ),
                              if (isPartiallySettled) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'of ${_formatAmount(entry.amount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Text(
                                  'Paid: ${_formatAmount(entry.settledAmount)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0F6B57),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            tooltip: 'Delete',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _deleteEntry(entry),
                          ),
                          // TextButton(
                          //   onPressed: () => _writeOffEntry(entry),
                          //   style: TextButton.styleFrom(
                          //     foregroundColor: Colors.red.shade700,
                          //     padding: const EdgeInsets.symmetric(
                          //       horizontal: 10,
                          //       vertical: 6,
                          //     ),
                          //   ),
                          // child: const Text(
                          //   'Write Off',
                          //   style: TextStyle(fontSize: 12),
                          // ),
                          // ),
                          if (!isPartiallySettled)
                            OutlinedButton.icon(
                              onPressed: () => _openAddOrEditEntryDialog(
                                existingEntry: entry,
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1E3A2F),
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () => _openSettlementDialog(entry),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: Text(
                              isPartiallySettled ? 'Settle Rest' : 'Settle',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F6B57),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

