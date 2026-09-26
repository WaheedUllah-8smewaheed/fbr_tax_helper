import re

file_path = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_builder = '''                          itemBuilder: (context, index) {
                            final data = categoryCards[index];
                            return _ParentCategoryCard(
                              data: data,
                              onTap: () => _openParentTransaction(
                                data.categoryName,
                                data.options,
                              ),
                            );
                          },'''

new_builder = '''                          itemBuilder: (context, index) {
                            final card = categoryCards[index];
                            return _AnimatedTransactionCategoryCard(
                              key: ValueKey('${_filter.name}-${card.categoryName}'),
                              data: card,
                              index: index,
                              onTap: () => _openParentTransaction(
                                card.categoryName,
                                card.options,
                              ),
                            );
                          },'''

content = content.replace(old_builder, new_builder)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed grid view item builder!")
