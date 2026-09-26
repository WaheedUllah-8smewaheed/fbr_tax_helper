part of '../../../dashboard/presentation/pages/dashboard_screen.dart';

class _AssetsPage extends StatefulWidget {
  const _AssetsPage({super.key, required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<_AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<_AssetsPage> {
  CategoryPreferencesService get _categoryPreferences =>
      widget.categoryPreferences;
  List<Asset> _assets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthService>().currentUser?.uid;
      final rows = await TaxDatabase.instance
          .fetchAssets(userId: userId)
          .timeout(const Duration(seconds: 2));
      final list = rows.map((r) => Asset.fromMap(r)).toList();
      if (mounted) {
        setState(() {
          _assets = list;
        });
      }
    } catch (_) {
      // Gracefully handle in tests
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

  double get _totalAssetsValue => _assets.fold(0.0, (sum, a) => sum + a.value);

  List<Asset> get _filteredAssets {
    return _assets.where((asset) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return asset.name.toLowerCase().contains(q) ||
          asset.category.displayName.toLowerCase().contains(q) ||
          asset.value.toString().contains(q) ||
          asset.value.toStringAsFixed(2).contains(q);
    }).toList();
  }

  IconData _iconForCategory(AssetCategory category) {
    return switch (category) {
      AssetCategory.cash => Icons.payments_outlined,
      AssetCategory.bank => Icons.account_balance_outlined,
      AssetCategory.property => Icons.home_work_outlined,
      AssetCategory.vehicle => Icons.directions_car_outlined,
      AssetCategory.investment => Icons.trending_up_rounded,
      AssetCategory.other => Icons.category_outlined,
    };
  }

  Color _colorForCategory(AssetCategory category) {
    return switch (category) {
      AssetCategory.cash => const Color(0xFF2E7D32),
      AssetCategory.bank => const Color(0xFF1565C0),
      AssetCategory.property => const Color(0xFFE65100),
      AssetCategory.vehicle => const Color(0xFF4527A0),
      AssetCategory.investment => const Color(0xFF6A1B9A),
      AssetCategory.other => const Color(0xFF00695C),
    };
  }

  Future<void> _openAddAssetSheet() async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final descriptionController = TextEditingController();
    AssetCategory selectedCategory = AssetCategory.cash;
    final formKey = GlobalKey<FormState>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (bottomSheetContext) => Scaffold(
          appBar: AppBar(title: const Text('Add Asset')),
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
                          const Text(
                            'Add Asset',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A2F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Initial asset record (opening balance). No expense/income will be logged.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: 'Title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter a name'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              hintText: 'Description (Optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<AssetCategory>(
                            initialValue: selectedCategory,
                            decoration: InputDecoration(
                              hintText: 'Category',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: AssetCategory.values.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat.displayName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedCategory = val);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: valueController,
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
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter value';
                              }
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null || parsed < 0) {
                                return 'Enter a valid non-negative number';
                              }
                              return null;
                            },
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
                                    final val = double.parse(
                                      valueController.text.trim(),
                                    );

                                    final now = DateTime.now();
                                    final newAsset = Asset(
                                      userId: userId,
                                      name: nameController.text.trim(),
                                      category: selectedCategory,
                                      value: val,
                                      createdAt: now,
                                      updatedAt: now,
                                    );

                                    await TaxDatabase.instance.insertAsset(
                                      newAsset.toMap(),
                                    );

                                    if (bottomSheetContext.mounted) {
                                      Navigator.pop(bottomSheetContext);
                                    }
                                    _loadAssets();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Asset added to ledger',
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
                                  child: const Text('Add Asset'),
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

  Future<void> _openEditAssetSheet(Asset asset) async {
    final messenger = ScaffoldMessenger.of(context);
    final changeController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isIncrease = false;
    var cashInvolved = true;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (assetEditContext) => Scaffold(
          appBar: AppBar(title: Text('Edit "${asset.name}"')),
          body: SafeArea(
            child: StatefulBuilder(
              builder: (builderContext, setModalState) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(builderContext).viewInsets.bottom +
                        MediaQuery.of(builderContext).padding.bottom +
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
                          const SizedBox(height: 8),
                          Text(
                            'Edit "${asset.name}"',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A2F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current recorded value: ${_formatAmount(asset.value)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text('Did the value go up or down? *'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _assetChoiceButton(
                                  label: '↓ Decreased',
                                  selected: !isIncrease,
                                  onPressed: () =>
                                      setModalState(() => isIncrease = false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _assetChoiceButton(
                                  label: '↑ Increased',
                                  selected: isIncrease,
                                  onPressed: () =>
                                      setModalState(() => isIncrease = true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: changeController,
                            onChanged: (_) => setModalState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'By how much (PKR)? *',
                              hintText: '0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter value';
                              }
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a valid positive number';
                              }
                              if (!isIncrease && parsed > asset.value) {
                                return 'Decrease cannot exceed current value';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: reasonController,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Reason (optional)',
                              hintText: 'Why is this asset value changing?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF0F2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Expanded(child: Text('Cash involved?')),
                                _assetChoiceButton(
                                  label: 'Yes',
                                  selected: cashInvolved,
                                  onPressed: () =>
                                      setModalState(() => cashInvolved = true),
                                ),
                                const SizedBox(width: 8),
                                _assetChoiceButton(
                                  label: 'No',
                                  selected: !cashInvolved,
                                  onPressed: () =>
                                      setModalState(() => cashInvolved = false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final entered =
                                  double.tryParse(
                                    changeController.text.trim(),
                                  ) ??
                                  0.0;
                              final preview = isIncrease
                                  ? asset.value + entered
                                  : asset.value - entered;
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5F8EC),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    const Text('New value will be'),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatAmount(preview),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF008A45),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pop(assetEditContext),
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
                                    final change = double.parse(
                                      changeController.text.trim(),
                                    );
                                    final reason = reasonController.text.trim();
                                    final newValue = isIncrease
                                        ? asset.value + change
                                        : asset.value - change;
                                    final valueChanged =
                                        (newValue - asset.value).abs() > 0.01;

                                    if (valueChanged && cashInvolved) {
                                      if (assetEditContext.mounted) {
                                        Navigator.pop(assetEditContext);
                                      }
                                      final transactionSaved =
                                          await _openAssetAdjustmentTransaction(
                                            asset,
                                            change,
                                            isIncrease,
                                            reason,
                                          );
                                      if (!transactionSaved || !mounted) {
                                        return;
                                      }
                                    }

                                    final updatedAsset = asset.copyWith(
                                      value: newValue,
                                      updatedAt: DateTime.now(),
                                    );

                                    await TaxDatabase.instance.updateAsset(
                                      updatedAsset.toMap(),
                                    );

                                    if (assetEditContext.mounted) {
                                      Navigator.pop(assetEditContext);
                                    }

                                    _loadAssets();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            valueChanged && cashInvolved
                                                ? 'Asset updated and transaction recorded'
                                                : 'Asset updated',
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
                                  child: const Text('Save Changes'),
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

  Future<bool> _openAssetAdjustmentTransaction(
    Asset asset,
    double amount,
    bool isIncrease,
    String reason,
  ) async {
    if (!mounted) return false;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _TransactionsPage(
          categoryPreferences: _categoryPreferences,
          filter: isIncrease
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
                  initialIsExpense: isIncrease,
                  initialAmount: amount,
                  initialPurpose: reason.isEmpty
                      ? asset.name
                      : '${asset.name}: $reason',
                  initialDate: DateTime.now(),
                  isSettlement: true,
                  assetId: asset.id,
                  linkedCounterpartyOrAsset: asset.name,
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
    return saved == true;
  }

  Widget _assetChoiceButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xFF003B2F)
              : Colors.transparent,
          foregroundColor: selected ? Colors.white : const Color(0xFF1E3A2F),
          side: BorderSide(
            color: selected ? const Color(0xFF003B2F) : const Color(0xFFD2E3DE),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Future<void> _deleteAsset(Asset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Asset?'),
          content: Text(
            'Delete "${asset.name}"? Previously recorded transactions will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
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

    if (confirmed == true && asset.id != null) {
      await TaxDatabase.instance.deleteAsset(asset.id!);
      _loadAssets();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Asset deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssets;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24.0;

    return RefreshIndicator(
      onRefresh: _loadAssets,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
        children: [
          // Top Banner
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Total Assets Value',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        '${_assets.length} assets',
                        style: const TextStyle(
                          color: AppColors.warmGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatAmount(_totalAssetsValue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vehicles, property, savings, cash, and investments',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Add Asset Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _openAddAssetSheet,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text(
                'Add Asset',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 14),

          // Search Field
          if (_assets.isNotEmpty)
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
                    Icons.account_balance_outlined,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No matching assets found'
                        : 'No assets recorded yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Add Asset" above to log vehicles, plots, bank savings, or gold.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((asset) {
              final color = _colorForCategory(asset.category);
              final icon = _iconForCategory(asset.category);
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF1E3A2F),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    asset.category.displayName,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatAmount(asset.value),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A2F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Updated: ${DateFormat('dd MMM yyyy').format(asset.updatedAt)}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                tooltip: 'Delete',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _deleteAsset(asset),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openEditAssetSheet(asset),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit Value'),
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
                            ],
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

