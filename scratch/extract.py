import re

with open('lib/features/khata/presentation/pages/khata_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

idx = content.find('Future<void> _openAddOrEditEntryDialog')
if idx == -1:
    print("Not found")
else:
    end_idx = content.find('Future<void> _openSettlementDialog', idx)
    with open('scratch/temp.dart', 'w', encoding='utf-8') as out:
        out.write(content[idx:end_idx])
    print("Extracted")
