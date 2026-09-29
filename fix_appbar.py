import os
p = 'lib/features/dashboard/presentation/pages/dashboard_screen.dart'
with open(p, 'r', encoding='utf-8') as f:
    c = f.read()

old_appbar = '''        appBar: _selectedIndex == 0
            ? null
            : AppBar(title: Text(titles[_selectedIndex])),'''

new_appbar = '''        appBar: _selectedIndex == 0
            ? null
            : AppBar(
                title: Text(titles[_selectedIndex]),
                actions: [
                  if (_selectedIndex == 1 || _selectedIndex == 2)
                    IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        if (_selectedIndex == 1) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryPage(
                                title: 'Payable/Receivable History',
                                mode: TransactionListMode.khata,
                              ),
                            ),
                          );
                        } else if (_selectedIndex == 2) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryPage(
                                title: 'Asset History',
                                mode: TransactionListMode.asset,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),'''

c = c.replace(old_appbar, new_appbar)

import1 = "import 'package:fbr_tax_helper/features/dashboard/presentation/pages/history_page.dart';"
import2 = "import 'package:fbr_tax_helper/features/transactions/presentation/pages/transaction_widgets.dart';"

if import1 not in c:
    c = import1 + '\n' + c
if import2 not in c:
    c = import2 + '\n' + c

with open(p, 'w', encoding='utf-8') as f:
    f.write(c)
print('Added history button to AppBar')
