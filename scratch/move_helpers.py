import os

with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    dashboard_content = f.read()

# Extract getIconForCategory
icon_idx = dashboard_content.find('IconData getIconForCategory(String category) {')
icon_end = dashboard_content.find('}', dashboard_content.find('case \'default\':', icon_idx)) + 3 # roughly the end
# actually, let's just find the end bracket of the function by counting
def find_end_bracket(text, start_idx):
    count = 0
    in_str = False
    for i in range(start_idx, len(text)):
        if text[i] == \"'\" or text[i] == '\"':
            in_str = not in_str
        if not in_str:
            if text[i] == '{':
                count += 1
            elif text[i] == '}':
                count -= 1
                if count == 0:
                    return i + 1
    return -1

if icon_idx != -1:
    icon_end = find_end_bracket(dashboard_content, dashboard_content.find('{', icon_idx))
    icon_str = dashboard_content[icon_idx:icon_end]
    dashboard_content = dashboard_content[:icon_idx] + dashboard_content[icon_end:]
else:
    icon_str = ''

# Extract _getColorForCategory
color_idx = dashboard_content.find('Color _getColorForCategory(String category) {')
if color_idx != -1:
    color_end = find_end_bracket(dashboard_content, dashboard_content.find('{', color_idx))
    color_str = dashboard_content[color_idx:color_end]
    dashboard_content = dashboard_content[:color_idx] + dashboard_content[color_end:]
else:
    color_str = ''

# rename _getColorForCategory to getColorForCategory
color_str = color_str.replace('Color _getColorForCategory', 'Color getColorForCategory')

with open('lib/features/dashboard/presentation/pages/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(dashboard_content)

# Add to transaction_widgets.dart
with open('lib/features/transactions/presentation/pages/transaction_widgets.dart', 'a', encoding='utf-8') as f:
    f.write('\n\n' + icon_str + '\n\n' + color_str + '\n')

# update transactions_page.dart to use getColorForCategory instead of _getColorForCategory
with open('lib/features/transactions/presentation/pages/transactions_page.dart', 'r', encoding='utf-8') as f:
    t_page = f.read()
t_page = t_page.replace('_getColorForCategory', 'getColorForCategory')
with open('lib/features/transactions/presentation/pages/transactions_page.dart', 'w', encoding='utf-8') as f:
    f.write(t_page)

print("Helpers moved")
