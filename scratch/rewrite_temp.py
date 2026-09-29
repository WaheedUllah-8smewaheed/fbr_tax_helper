import re

with open('scratch/temp.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Remove fromIncome checkbox block
checkbox_pattern = r'if \(!isPayable\)\s*CheckboxListTile\(.*?\),\s*const SizedBox\(height: 22\),'
code = re.sub(checkbox_pattern, 'const SizedBox(height: 22),', code, flags=re.DOTALL)

# 2. Modify entryToSave
entry_save_pattern = r'fromIncome: fromIncome,'
code = re.sub(entry_save_pattern, 'fromIncome: false,', code)

# 3. Replace the if (isEditing) ... else block and everything until if (bottomSheetContext.mounted) { Navigator.pop(bottomSheetContext); }
old_logic_pattern = r'if \(isEditing\) \{.*?context\.read<KhataBloc>\(\)\.add\(LoadKhataEntries\(userId: context\.read<AuthService>\(\)\.currentUser\?\.uid \?\? \'\'\)\);'

new_logic = '''if (isEditing) {
                                      await TaxDatabase.instance.updateKhataEntry(entryToSave.toMap());
                                      if (bottomSheetContext.mounted) {
                                        Navigator.pop(bottomSheetContext);
                                      }
                                      if (mounted) {
                                        context.read<KhataBloc>().add(LoadKhataEntries(userId: context.read<AuthService>().currentUser?.uid ?? ''));
                                      }
                                    } else {
                                      final result = await Navigator.of(bottomSheetContext).push<Map<String, dynamic>>(
                                        MaterialPageRoute(
                                          builder: (ctx) => TransactionsPage(
                                            categoryPreferences: _categoryPreferences,
                                            filter: isPayable ? TransactionTypeFilter.income : TransactionTypeFilter.expense,
                                            onFilterChanged: (_) {},
                                            showAppBar: true,
                                            showTypeFilter: true,
                                            isSettlement: true,
                                            isPayableSettlement: !isPayable,
                                            onParentCategorySelected: (parentCategory, categoryOptions) async {
                                              String? selectedCategory = parentCategory;
                                              if (categoryOptions.isNotEmpty) {
                                                selectedCategory = await showDialog<String>(
                                                  context: ctx,
                                                  builder: (ctx2) => SimpleDialog(
                                                    title: Text('Select Subcategory for \'),
                                                    children: categoryOptions.map((c) => SimpleDialogOption(
                                                      onPressed: () => Navigator.pop(ctx2, c.name),
                                                      child: Text(c.name),
                                                    )).toList(),
                                                  )
                                                );
                                              }
                                              if (selectedCategory != null && ctx.mounted) {
                                                Navigator.pop(ctx, {'type': 'category', 'category': selectedCategory});
                                              }
                                            },
                                            onAssetSelected: (asset) async {
                                              Navigator.pop(ctx, {'type': 'asset', 'asset': asset});
                                            }
                                          )
                                        )
                                      );

                                      if (result == null || !bottomSheetContext.mounted) {
                                        return; 
                                      }

                                      final newKhataId = await TaxDatabase.instance.insertKhataEntry(entryToSave.toMap());
                                      
                                      if (result['type'] == 'asset') {
                                         final asset = result['asset'] as Map<String, dynamic>;
                                         double newAssetValue = (asset['value'] as num).toDouble();
                                         if (isPayable) {
                                           newAssetValue += amount; 
                                         } else {
                                           newAssetValue -= amount; 
                                         }
                                         await TaxDatabase.instance.updateAsset({
                                           'id': asset['id'],
                                           'value': newAssetValue,
                                           'updatedAt': DateTime.now().toIso8601String(),
                                         });
                                         
                                         await TaxDatabase.instance.insertTransaction({
                                           'userId': userId,
                                           'title': isPayable ? 'Added Payable: \' : 'Added Receivable: \',
                                           'beneficiary': entryToSave.party,
                                           'purpose': 'Khata Entry',
                                           'amount': amount,
                                           'isExpense': isPayable ? 0 : 1, 
                                           'date': entryToSave.date.toIso8601String(),
                                           'category': isPayable ? 'Asset Deposit' : 'Asset Withdrawal',
                                           'khataEntryId': newKhataId,
                                           'assetId': asset['id'],
                                           'linkedCounterpartyOrAsset': asset['name'],
                                         });
                                      } else {
                                         final category = result['category'] as String;
                                         await TaxDatabase.instance.insertTransaction({
                                           'userId': userId,
                                           'title': isPayable ? 'Added Payable: \' : 'Added Receivable: \',
                                           'beneficiary': entryToSave.party,
                                           'purpose': 'Khata Entry',
                                           'amount': amount,
                                           'isExpense': isPayable ? 0 : 1, 
                                           'date': entryToSave.date.toIso8601String(),
                                           'category': category,
                                           'khataEntryId': newKhataId,
                                         });
                                      }

                                      if (bottomSheetContext.mounted) {
                                        bottomSheetContext.read<TransactionBloc>().add(LoadTransactions());
                                        Navigator.pop(bottomSheetContext);
                                      }
                                      if (mounted) {
                                        context.read<KhataBloc>().add(LoadKhataEntries(userId: context.read<AuthService>().currentUser?.uid ?? ''));
                                      }
                                    }'''

code = re.sub(old_logic_pattern, new_logic, code, flags=re.DOTALL)

with open('scratch/temp.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Done")
