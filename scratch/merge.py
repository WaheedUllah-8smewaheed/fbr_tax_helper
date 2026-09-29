import re

with open('lib/features/khata/presentation/pages/khata_page.dart', 'r', encoding='utf-8') as f:
    orig = f.read()

idx = orig.find('Future<void> _openAddOrEditEntryDialog')
end_idx = orig.find('Future<void> _openSettlementDialog', idx)

with open('scratch/temp.dart', 'r', encoding='utf-8') as f:
    new_method = f.read()

merged = orig[:idx] + new_method + orig[end_idx:]

with open('lib/features/khata/presentation/pages/khata_page.dart', 'w', encoding='utf-8') as f:
    f.write(merged)
print("Merged")
