import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()


# 1. Khata Entry Dialog UI additions
code = code.replace(
'''    final partyController = TextEditingController(
      text: existingEntry?.party ?? '',
    );
    final formKey = GlobalKey<FormState>();''',
'''    final partyController = TextEditingController(
      text: existingEntry?.party ?? '',
    );
    bool fromIncome = existingEntry?.fromIncome ?? false;
    final formKey = GlobalKey<FormState>();'''
)

khata_checkbox_pattern = r'''                          const SizedBox\(height: 22\),
                          Row\(
                            children: \['''

khata_checkbox_replacement = '''                          if (!isPayable)
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
                            children: ['''

if 'Minimize this amount from total income' not in code:
    code = re.sub(khata_checkbox_pattern, khata_checkbox_replacement, code, count=1)


khata_save_pattern = r'''                                    final entryToSave = KhataEntry\(
                                      id: existingEntry\?\.id,
                                      userId: userId,
                                      title: titleController\.text\.trim\(\),
                                      party: partyController\.text\.trim\(\),
                                      amount: amount,
                                      isPayable: isPayable,
                                      date:
                                          existingEntry\?\.date \?\? DateTime\.now\(\),
                                      dueDate: existingEntry\?\.dueDate,
                                      description:
                                          existingEntry\?\.description \?\? '',
                                      isPaid: existingEntry != null
                                          \? \(existingEntry\.settledAmount >=
                                                amount\)
                                          : false,
                                      settledAmount:
                                          existingEntry\?\.settledAmount \?\? 0\.0,
                                      isWrittenOff:
                                          existingEntry\?\.isWrittenOff \?\? false,
                                    \);

                                    if \(isEditing\) \{
                                      await TaxDatabase\.instance
                                          \.updateKhataEntry\(
                                            entryToSave\.toMap\(\),
                                          \);
                                    \} else \{
                                      await TaxDatabase\.instance
                                          \.insertKhataEntry\(
                                            entryToSave\.toMap\(\),
                                          \);
                                    \}'''


khata_save_replacement = '''                                    final entryToSave = KhataEntry(
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
                                         final tx = entity.Transaction(
                                            userId: userId,
                                            title: 'Receivable: ${entryToSave.title}',
                                            beneficiary: entryToSave.party,
                                            purpose: 'Khata Loan (From Income)',
                                            amount: amount,
                                            isExpense: true,
                                            date: entryToSave.date,
                                            category: 'Khata',
                                            khataEntryId: newKhataId,
                                         );
                                         await TaxDatabase.instance.insertTransaction(tx.toMap());
                                         if (bottomSheetContext.mounted) {
                                           bottomSheetContext.read<TransactionBloc>().add(LoadTransactions(userId));
                                         }
                                      }
                                    }'''

code = re.sub(khata_save_pattern, khata_save_replacement, code, count=1)


# 2. Add description to Add Asset
add_asset_vars_pattern = r'''    final messenger = ScaffoldMessenger\.of\(context\);
    final nameController = TextEditingController\(\);
    final valueController = TextEditingController\(\);
    AssetCategory selectedCategory = AssetCategory\.cash;
    final formKey = GlobalKey<FormState>\(\);'''

add_asset_vars_replacement = '''    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final descriptionController = TextEditingController();
    AssetCategory selectedCategory = AssetCategory.cash;
    final formKey = GlobalKey<FormState>();'''

code = re.sub(add_asset_vars_pattern, add_asset_vars_replacement, code, count=1)


add_asset_ui_pattern = r'''                          DropdownButtonFormField<AssetCategory>\(
                            initialValue: selectedCategory,
                            decoration: InputDecoration\('''

add_asset_ui_replacement = '''                          TextFormField(
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
                            decoration: InputDecoration('''

if 'Description (Optional)' not in code:
    code = re.sub(add_asset_ui_pattern, add_asset_ui_replacement, code, count=1)


add_asset_save_pattern = r'''                                    final asset = Asset\(
                                      userId: userId,
                                      name: nameController\.text\.trim\(\),
                                      category: selectedCategory,
                                      value: double\.parse\(
                                        valueController\.text\.trim\(\),
                                      \),
                                      createdAt: now,
                                      updatedAt: now,
                                    \);'''

add_asset_save_replacement = '''                                    final asset = Asset(
                                      userId: userId,
                                      name: nameController.text.trim(),
                                      category: selectedCategory,
                                      value: double.parse(
                                        valueController.text.trim(),
                                      ),
                                      createdAt: now,
                                      updatedAt: now,
                                      description: descriptionController.text.trim(),
                                    );'''

code = re.sub(add_asset_save_pattern, add_asset_save_replacement, code, count=1)


with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("dashboard_screen.dart updated!")
