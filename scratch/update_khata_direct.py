import re

file_path = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\khata\presentation\pages\khata_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('Future<void> _openSettlementDialog(KhataEntry entry) async {')
end_idx = content.find('  // Future<void> _writeOffEntry(KhataEntry entry) async {', start_idx)

if start_idx != -1 and end_idx != -1:
    new_func = '''Future<void> _openSettlementDialog(KhataEntry entry) async {
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
          showTypeFilter: true, // We now want to show the toggle!
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
              Navigator.of(context).pop(true);
            }
          },
          onAssetSelected: (selectedAsset) async {
            final amountController = TextEditingController(text: remaining.toStringAsFixed(0));
            final amount = await showDialog<double>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Settlement Amount'),
                content: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount to settle',
                    prefixText: 'PKR ',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final val = double.tryParse(amountController.text.replaceAll(',', ''));
                      if (val != null && val > 0) {
                        Navigator.pop(context, val);
                      }
                    },
                    child: const Text('Settle'),
                  ),
                ],
              ),
            );

            if (amount == null || !mounted) return;

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

            final newSettledAmount = entry.settledAmount + amount;
            final isFullySettled = newSettledAmount >= entry.amount - 0.001;

            await TaxDatabase.instance.updateKhataEntry(
              entry.copyWith(settledAmount: newSettledAmount, isPaid: isFullySettled).toMap(),
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isPayable 
                  ? 'Settled! Deducted PKR $amount from ${selectedAsset['name']}' 
                  : 'Settled! Added PKR $amount to ${selectedAsset['name']}'),
                backgroundColor: const Color(0xFF0F6B57),
              ),
            );

            Navigator.of(context).pop(true);
          },
        ),
      ),
    );

    if (saved == true && mounted) {
      await _loadEntries();
    }
  }

'''
    content = content[:start_idx] + new_func + content[end_idx:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced _openSettlementDialog successfully.")
else:
    print("Could not find start or end index!")
