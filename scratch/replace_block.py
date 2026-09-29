import re

with open('lib/features/khata/presentation/pages/khata_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r'Future<void> _openAddOrEditEntryDialog\(.*?child: Text\(\s*isEditing\s*\?\s*\'Save Changes\'\s*:\s*\(isPayable\s*\?\s*\'Add Payable\'\s*:\s*\'Add Receivable\'\),\s*\),\s*\),\s*\),\s*\]\,\s*\),\s*\]\,\s*\),\s*\),\s*\),\s*\),\s*\);\s*\}', re.DOTALL)

match = pattern.search(content)
if not match:
    print("Match failed")
else:
    print("Match found!")
