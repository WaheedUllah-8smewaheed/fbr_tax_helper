import 'dart:async';
import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';
import 'package:fbr_tax_helper/features/khata/domain/entities/khata_entry.dart';
import 'package:fbr_tax_helper/features/khata/presentation/bloc/khata_bloc.dart';
import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';




enum KhataSegmentFilter { payable, receivable }

class KhataPage extends StatefulWidget {
  const KhataPage({super.key, required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  @override
  State<KhataPage> createState() => KhataPageState();
}

class KhataPageState extends State<KhataPage> {
  KhataSegmentFilter _selectedFilter = KhataSegmentFilter.payable;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthService>().currentUser?.uid ?? '';
    context.read<KhataBloc>().add(LoadKhataEntries(userId: userId));
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


  double _getTotalPayable(List<KhataEntry> entries) => entries
      .where((e) => e.isPayable && !e.isPaid && !e.isWrittenOff)
      .fold(0.0, (sum, e) => sum + e.remainingAmount);

  double _getTotalReceivable(List<KhataEntry> entries) => entries
      .where((e) => !e.isPayable && !e.isPaid && !e.isWrittenOff)
      .fold(0.0, (sum, e) => sum + e.remainingAmount);

  double _getNetBalance(List<KhataEntry> entries) => _getTotalReceivable(entries) - _getTotalPayable(entries);

  List<KhataEntry> _getFilteredEntries(List<KhataEntry> entries) {
    return entries.where((entry) {
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
          entry.description.toLowerCase().contains(q);
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
    ScaffoldMessenger.of(context);
    final isEditing = existingEntry != null;
    final isPayable = existingEntry?.isPayable ??
        (isPayableDefault ?? _selectedFilter == KhataSegmentFilter.payable);

    final titleController = TextEditingController(text: existingEntry?.title);
    final partyController = TextEditingController(text: existingEntry?.party);
    final amountController = TextEditingController(
      text: existingEntry != null
          ? existingEntry.amount.toStringAsFixed(0)
          : '',
    );
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
                            controller: titleController,
                            decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Loan to friend'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: partyController,
                            decoration: InputDecoration(labelText: isPayable ? 'To whom?' : 'From whom?'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Amount (PKR)'),
                            validator: (v) => v == null || v.trim().isEmpty || double.tryParse(v) == null ? 'Valid amount required' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final user = context.read<AuthService>().currentUser;
                                final userId = user?.uid ?? '';
                                final amount = double.parse(amountController.text.trim());

                                final entryToSave = KhataEntry(
                                  id: existingEntry?.id,
                                  userId: userId,
                                  title: titleController.text.trim(),
                                  party: partyController.text.trim(),
                                  amount: amount,
                                  isPayable: isPayable,
                                  date: existingEntry?.date ?? DateTime.now(),
                                  dueDate: existingEntry?.dueDate,
                                  description: existingEntry?.description ?? '',
                                  isPaid: existingEntry != null ? (existingEntry.settledAmount >= amount) : false,
                                  settledAmount: existingEntry?.settledAmount ?? 0.0,
                                  isWrittenOff: existingEntry?.isWrittenOff ?? false,
                                  fromIncome: false,
                                );

                                if (isEditing) {
                                  await TaxDatabase.instance.updateKhataEntry(entryToSave.toMap());
                                  await TaxDatabase.instance.insertTransaction({
                                    'userId': userId,
                                    'title': isPayable ? 'Edited Payable' : 'Edited Receivable',
                                    'beneficiary': entryToSave.party,
                                    'purpose': 'Edited details/amount',
                                    'amount': amount,
                                    'isExpense': 0,
                                    'date': DateTime.now().toIso8601String(),
                                    'category': 'Khata History',
                                    'khataEntryId': existingEntry.id,
                                  });
                                } else {
                                  final entryId = await TaxDatabase.instance.insertKhataEntry(entryToSave.toMap());
                                  await TaxDatabase.instance.insertTransaction({
                                    'userId': userId,
                                    'title': isPayable ? 'Added Payable' : 'Added Receivable',
                                    'beneficiary': entryToSave.party,
                                    'purpose': 'Initial creation',
                                    'amount': amount,
                                    'isExpense': 0,
                                    'date': DateTime.now().toIso8601String(),
                                    'category': 'Khata History',
                                    'khataEntryId': entryId,
                                  });
                                }
                                
                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(bottomSheetContext);
                                }
                                if (mounted) {
                                  context.read<KhataBloc>().add(LoadKhataEntries(userId: context.read<AuthService>().currentUser?.uid ?? ''));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F6B57),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(isEditing ? 'Save Changes' : (isPayable ? 'Add Payable' : 'Add Receivable')),
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

  Future<void> _openSettlementDialog(KhataEntry entry) async {
    final remaining = entry.remainingAmount;
    if (!mounted) return;

    final amountController = TextEditingController(text: remaining.toStringAsFixed(0));
    final descController = TextEditingController();
    
    final val = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settle '),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Paid in cash'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount to settle', prefixText: 'PKR '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amountVal = double.tryParse(amountController.text.replaceAll(',', ''));
              if (amountVal != null && amountVal > 0) {
                Navigator.pop(context, {'amount': amountVal, 'desc': descController.text.trim()});
              }
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );

    if (val != null && mounted) {
      final amount = val['amount'] as double;
      final desc = val['desc'] as String;
      
      final newSettledAmount = entry.settledAmount + amount;
      final isFullySettled = newSettledAmount >= entry.amount - 0.001;
      
      await TaxDatabase.instance.updateKhataEntry(
        entry.copyWith(settledAmount: newSettledAmount, isPaid: isFullySettled).toMap(),
      );

      await TaxDatabase.instance.insertTransaction({
        'userId': entry.userId,
        'title': entry.isPayable ? 'Settled Payable' : 'Settled Receivable',
        'beneficiary': entry.party,
        'purpose': desc.isNotEmpty ? desc : 'Settlement',
        'amount': amount,
        'isExpense': 0,
        'date': DateTime.now().toIso8601String(),
        'category': 'Khata History',
        'khataEntryId': entry.id,
      });

      if (mounted) {
        context.read<KhataBloc>().add(LoadKhataEntries(userId: context.read<AuthService>().currentUser?.uid ?? ''));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFullySettled ? 'Fully settled!' : 'Settlement recorded.'),
            backgroundColor: const Color(0xFF0F6B57),
          ),
        );
      }
    }
  }

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
      // ignore: use_build_context_synchronously
      context.read<KhataBloc>().add(LoadKhataEntries(userId: context.read<AuthService>().currentUser?.uid ?? ''));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Khata entry deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KhataBloc, KhataState>(
      builder: (context, state) {
        final List<KhataEntry> entries = state is KhataLoaded ? state.entries : [];
        final bool isLoading = state is KhataLoading;
        final filtered = _getFilteredEntries(entries);
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 96.0;

        return RefreshIndicator(
          onRefresh: () async {
            final userId = context.read<AuthService>().currentUser?.uid ?? '';
            context.read<KhataBloc>().add(LoadKhataEntries(userId: userId));
          },
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
                        'Net: ${_formatAmount(_getNetBalance(entries))}',
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
                                _formatAmount(_getTotalPayable(entries)),
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
                                _formatAmount(_getTotalReceivable(entries)),
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
          if (entries.isNotEmpty)
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
      },
    );
  }
}

