import re

file_path = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the else if with just if
content = content.replace(
    '] else if (transaction.assetId != null) ...[',
    ']\n                        if (transaction.assetId != null) ...['
)

start_search = '              Row(\n                mainAxisAlignment: MainAxisAlignment.end,\n                children: [\n                  TextButton.icon('

end_search = '                  ),\n                ],\n              ),\n            ],\n          ),\n        ),\n      );\n    }\n'

start_idx = content.find(start_search)
end_idx = content.find(end_search, start_idx)

if start_idx != -1 and end_idx != -1:
    end_idx += len(end_search)
    old_buttons = content[start_idx:end_idx]
    
    new_buttons = old_buttons.replace('              Row(\n', '              if (transaction.khataEntryId == null && transaction.assetId == null) ...[\n                Row(\n')
    new_buttons = new_buttons.replace('                ],\n              ),\n            ],\n          ),\n        ),\n      );\n    }\n', '                ],\n              ),\n              ],\n            ],\n          ),\n        ),\n      );\n    }\n')
    
    content = content[:start_idx] + new_buttons + content[end_idx:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Updated _TransactionTile!")
else:
    print("Could not find search_buttons!")
