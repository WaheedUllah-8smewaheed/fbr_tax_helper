import re

file_path = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\khata\presentation\pages\khata_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# We need to replace the _openSettlementDialog entirely.
start_search = 'Future<void> _openSettlementDialog(KhataEntry entry) async {'
end_search = '  // Future<void> _writeOffEntry(KhataEntry entry) async {'

start_idx = content.find(start_search)
end_idx = content.find(end_search, start_idx)

if start_idx != -1 and end_idx != -1:
    new_func = '''Future<void> _openSettlementDialog(KhataEntry entry) async {
    final remaining = entry.remainingAmount;
    if (!mounted) return;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => _TransactionsPage(
          categoryPreferences: _categoryPreferences,
          filter: entry.isPayable
              ? TransactionTypeFilter.expense
              : TransactionTypeFilter.income,
          onFilterChanged: (_) {},
          showAppBar: true,
          showTypeFilter: true,
          isSettlement: true,
          isPayableSettlement: entry.isPayable,
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
              Navigator.of(context).pop({'type': 'category', 'amount': remaining});
            }
          },
          onAssetSelected: (selectedAsset) async {
            final amountController = TextEditingController(text: remaining.toStringAsFixed(0));
            final descController = TextEditingController();
            final assetValueStr = 'PKR ${(selectedAsset['value'] as num).toStringAsFixed(0)}';

            final val = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Asset Settlement'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: assetValueStr),
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Asset Value',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g. Paid via bank transfer',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount to settle',
                        prefixText: 'PKR ',
                      ),
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

            if (val == null || !mounted) return;

            final amount = val['amount'] as double;
            final desc = val['desc'] as String;
            
            final isPayable = entry.isPayable;
            double newAssetValue = (selectedAsset['value'] as num).toDouble();
            
            if (isPayable) {
              newAssetValue -= amount;
            } else {
              newAssetValue += amount;
            }

            await TaxDatabase.instance.updateAsset({
              'id': selectedAsset['id'],
              'value': newAssetValue,
              'updatedAt': DateTime.now().toIso8601String(),
            });

            // Create a Transaction for the asset settlement so the description is saved
            await TaxDatabase.instance.insertTransaction({
              'userId': entry.userId,
              'title': isPayable ? 'Settled Payable' : 'Settled Receivable',
              'beneficiary': entry.party,
              'purpose': desc.isNotEmpty ? desc : 'Asset Settlement',
              'amount': amount,
              'isExpense': isPayable ? 1 : 0,
              'date': DateTime.now().toIso8601String(),
              'category': 'Asset Settlement',
              'khataEntryId': entry.id,
              'assetId': selectedAsset['id'],
            });

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isPayable 
                  ? 'Settled! Deducted PKR $amount from ${selectedAsset['name']}' 
                  : 'Settled! Added PKR $amount to ${selectedAsset['name']}'),
                backgroundColor: const Color(0xFF0F6B57),
              ),
            );

            Navigator.of(context).pop({'type': 'asset', 'amount': amount});
          },
        ),
      ),
    );

    if (result != null && mounted) {
      final type = result['type'] as String;
      final amount = result['amount'] as double;
      
      final newSettledAmount = entry.settledAmount + amount;
      final isFullySettled = newSettledAmount >= entry.amount - 0.001;

      await TaxDatabase.instance.updateKhataEntry(
        entry.copyWith(settledAmount: newSettledAmount, isPaid: isFullySettled).toMap(),
      );

      await _loadEntries();
      
      if (type == 'category' && mounted) {
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
  }

'''
    content = content[:start_idx] + new_func + content[end_idx:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Updated Khata settlement dialog!")
else:
    print("Failed to find indices!")
