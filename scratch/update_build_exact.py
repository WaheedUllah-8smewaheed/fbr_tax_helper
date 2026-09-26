import re

file_path = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('  Widget build(BuildContext context) {\n    return ListenableBuilder(\n      listenable: widget.categoryPreferences,\n      builder: (context, _) {\n        final categoryCards = _visibleCategoryCards();')

# We find the end of this build method. It ends with:
#       },
#     );
#   }
end_search = '      },\n    );\n  }'
end_idx = content.find(end_search, start_idx)

if start_idx != -1 and end_idx != -1:
    end_idx += len(end_search)
    new_build = '''  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.categoryPreferences,
      builder: (context, _) {
        final categoryCards = _visibleCategoryCards();

        final bottomPadding = MediaQuery.paddingOf(context).bottom + 90.0;
        return Scaffold(
          appBar: widget.showAppBar
              ? AppBar(
                  title: const Text('Transactions'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                )
              : null,
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            children: [
                _buildIntroCard(),
              if (widget.showTypeFilter) ...[
                widget.isSettlement
                    ? SegmentedButton<bool>(
                        expandedInsets: EdgeInsets.zero,
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(widget.isPayableSettlement == true ? 'Expense' : 'Income'),
                          ),
                          const ButtonSegment(
                            value: true,
                            label: Text('Asset'),
                          ),
                        ],
                        selected: {_showAssets},
                        onSelectionChanged: (selection) {
                          setState(() => _showAssets = selection.first);
                        },
                      )
                    : SegmentedButton<TransactionTypeFilter>(
                        expandedInsets: EdgeInsets.zero,
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: TransactionTypeFilter.income,
                            label: Text('Income'),
                          ),
                          ButtonSegment(
                            value: TransactionTypeFilter.expense,
                            label: Text('Expense'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _filter = selection.first;
                          });
                          widget.onFilterChanged(selection.first);
                        },
                      ),
                const SizedBox(height: 20),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _showAssets
                    ? (_assets == null
                        ? const Center(child: CircularProgressIndicator())
                        : _assets!.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No assets found.'),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _assets!.length,
                                itemBuilder: (context, index) {
                                  final asset = _assets![index];
                                  return Card(
                                    elevation: 0,
                                    color: Colors.grey.shade50,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0F6B57)),
                                      title: Text(asset['name']),
                                      subtitle: Text('Balance: PKR ${asset['value']}'),
                                      onTap: () {
                                        if (widget.onAssetSelected != null) {
                                          widget.onAssetSelected!(asset);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ))
                    : LayoutBuilder(
                        key: ValueKey(_filter),
                        builder: (context, constraints) => GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categoryCards.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: constraints.maxWidth < 360 ? 1.12 : 1.3,
                          ),
                          itemBuilder: (context, index) {
                            final data = categoryCards[index];
                            return _ParentCategoryCard(
                              data: data,
                              onTap:
                                  () => _openParentTransaction(
                                    data.categoryName,
                                    data.options,
                                  ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }'''
    content = content[:start_idx] + new_build + content[end_idx:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced build successfully!")
else:
    print(f"Failed to find indices. start={start_idx} end={end_idx}")
