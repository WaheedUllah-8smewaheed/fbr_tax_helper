// ignore_for_file: unused_local_variable, unnecessary_import

import 'dart:async';
import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';
import 'package:fbr_tax_helper/features/assets/domain/entities/asset.dart';
import 'package:fbr_tax_helper/features/assets/presentation/bloc/asset_bloc.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fbr_tax_helper/core/utils/comma_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:intl/intl.dart';



class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key, required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<AssetsPage> createState() => AssetsPageState();
}

class AssetsPageState extends State<AssetsPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthService>().currentUser?.uid ?? '';
    context.read<AssetBloc>().add(LoadAssets(userId: userId));
                                    context.read<TransactionBloc>().add(LoadTransactions());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'Rs ${formatter.format(amount)}';
  }

  double _getTotalAssetsValue(List<Asset> assets) => assets.fold(0.0, (sum, a) => sum + a.value);

  List<Asset> _getFilteredAssets(List<Asset> assets) {
    return assets.where((asset) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return asset.name.toLowerCase().contains(q) ||
          asset.category.displayName.toLowerCase().contains(q) ||
          asset.description.toLowerCase().contains(q);
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
                    bottom: mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 20,
                    top: 20, left: 20, right: 20,
                  ),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Asset Name', hintText: 'e.g. Bank Account'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: valueController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CommaTextInputFormatter()],
                            decoration: const InputDecoration(labelText: 'Current Value (PKR)'),
                            validator: (v) => v == null || v.trim().isEmpty || double.tryParse(v.replaceAll(',', '')) == null ? 'Valid amount required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: descriptionController,
                            decoration: const InputDecoration(labelText: 'Description (Optional)'),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final user = context.read<AuthService>().currentUser;
                                final userId = user?.uid ?? '';
                                final value = double.parse(valueController.text.trim().replaceAll(',', ''));

                                final assetToSave = Asset(
                                  userId: userId,
                                  name: nameController.text.trim(),
                                  value: value,
                                  description: descriptionController.text.trim(),
                                  category: selectedCategory,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                final assetId = await TaxDatabase.instance.insertAsset(assetToSave.toMap());
                                
                                await TaxDatabase.instance.insertTransaction({
                                  'userId': userId,
                                  'title': 'Asset Created',
                                  'beneficiary': assetToSave.name,
                                  'purpose': 'Initial value',
                                  'amount': value,
                                  'isExpense': 0,
                                  'date': DateTime.now().toIso8601String(),
                                  'category': 'Asset History',
                                  'assetId': assetId,
                                });

                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(bottomSheetContext);
                                }
                                if (mounted) {
                                  context.read<AssetBloc>().add(LoadAssets(userId: userId));
                                    context.read<TransactionBloc>().add(LoadTransactions());
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F6B57),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Add Asset'),
                            ),
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

  Future<void> _openAssetEditSheet(Asset asset) async {
    final messenger = ScaffoldMessenger.of(context);
    final changeController = TextEditingController();
    final reasonController = TextEditingController();
    bool isIncrease = true;
    double changeAmount = 0;
    final formKey = GlobalKey<FormState>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (assetEditContext) => Scaffold(
          appBar: AppBar(title: Text('Edit ')),
          body: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (builderContext, setModalState) {
                final mediaQuery = MediaQuery.of(builderContext);
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: EdgeInsets.only(
                    bottom: mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 20,
                    top: 20, left: 20, right: 20,
                  ),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Current Value: ${_formatAmount(asset.value)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _assetChoiceButton(
                                  label: 'Increase (+)',
                                  selected: isIncrease,
                                  onPressed: () => setModalState(() => isIncrease = true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _assetChoiceButton(
                                  label: 'Decrease (-)',
                                  selected: !isIncrease,
                                  onPressed: () => setModalState(() => isIncrease = false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: changeController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CommaTextInputFormatter()],
                            decoration: const InputDecoration(labelText: 'Amount Change (PKR)'),
                            onChanged: (value) => setModalState(
                              () => changeAmount =
                                  double.tryParse(value.replaceAll(',', '')) ?? 0,
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                (value ?? '').replaceAll(',', ''),
                              );
                              if (amount == null || amount <= 0) {
                                return 'Valid amount required';
                              }
                              if (!isIncrease && amount > asset.value) {
                                return 'Cannot decrease more than current value';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Value after ${isIncrease ? 'increase' : 'decrease'}: '
                            '${_formatAmount(isIncrease ? asset.value + changeAmount : asset.value - changeAmount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isIncrease
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: reasonController,
                            decoration: const InputDecoration(labelText: 'Reason for change'),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final change = double.parse(changeController.text.trim().replaceAll(',', ''));
                                final reason = reasonController.text.trim();
                                final newValue = isIncrease ? asset.value + change : asset.value - change;

                                final updatedAsset = asset.copyWith(value: newValue, updatedAt: DateTime.now());
                                context.read<AssetBloc>().add(UpdateAsset(asset: updatedAsset));

                                await TaxDatabase.instance.insertTransaction({
                                  'userId': asset.userId,
                                  'title': isIncrease ? 'Asset Value Increased' : 'Asset Value Decreased',
                                  'beneficiary': asset.name,
                                  'purpose': reason.isNotEmpty ? reason : 'Manual Adjustment',
                                  'amount': change,
                                  'isExpense': !isIncrease ? 1 : 0,
                                  'date': DateTime.now().toIso8601String(),
                                  'category': 'Asset History',
                                  'assetId': asset.id,
                                });

                                if (assetEditContext.mounted) {
                                  Navigator.pop(assetEditContext);
                                }
                                if (mounted) {
                                  context.read<AssetBloc>().add(LoadAssets(userId: context.read<AuthService>().currentUser?.uid ?? ''));
                                    context.read<TransactionBloc>().add(LoadTransactions());
                                  messenger.showSnackBar(const SnackBar(content: Text('Asset updated and history recorded')));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F6B57),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Save Changes'),
                            ),
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
      // ignore: use_build_context_synchronously
      context.read<AssetBloc>().add(LoadAssets(userId: context.read<AuthService>().currentUser?.uid ?? ''));
                                    // ignore: use_build_context_synchronously
                                    context.read<TransactionBloc>().add(LoadTransactions());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Asset deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssetBloc, AssetState>(
      builder: (context, state) {
        final List<Asset> assets = state is AssetLoaded ? state.assets : [];
        final bool isLoading = state is AssetLoading;
        final filtered = _getFilteredAssets(assets);
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 24.0;

        return RefreshIndicator(
          onRefresh: () async {
            final userId = context.read<AuthService>().currentUser?.uid ?? '';
            context.read<AssetBloc>().add(LoadAssets(userId: userId));
                                    context.read<TransactionBloc>().add(LoadTransactions());
          },
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
                        '${assets.length} assets',
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
                    _formatAmount(_getTotalAssetsValue(assets)),
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
          if (assets.isNotEmpty)
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
          if (isLoading)
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
                                  color: Color.fromARGB(255, 238, 3, 3),
                                ),
                                tooltip: 'Delete',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _deleteAsset(asset),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openAssetEditSheet(asset),
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
      },
    );
  }
}
