import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

khata_save_pattern = r'''                                         final tx = entity\.Transaction\(
                                            userId: userId,
                                            title: 'Receivable: \$\{entryToSave\.title\}',
                                            beneficiary: entryToSave\.party,
                                            purpose: 'Khata Loan \(From Income\)',
                                            amount: amount,
                                            isExpense: true,
                                            date: entryToSave\.date,
                                            category: 'Khata',
                                            khataEntryId: newKhataId,
                                         \);
                                         await TaxDatabase\.instance\.insertTransaction\(tx\.toMap\(\)\);'''

khata_save_replacement = '''                                         await TaxDatabase.instance.insertTransaction({
                                            'userId': userId,
                                            'title': 'Receivable: ${entryToSave.title}',
                                            'beneficiary': entryToSave.party,
                                            'purpose': 'Khata Loan (From Income)',
                                            'amount': amount,
                                            'isExpense': 1,
                                            'date': entryToSave.date.toIso8601String(),
                                            'category': 'Khata',
                                            'khataEntryId': newKhataId,
                                         });'''

code = re.sub(khata_save_pattern, khata_save_replacement, code, count=1)

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Fixed insertTransaction in dashboard_screen.dart!")
