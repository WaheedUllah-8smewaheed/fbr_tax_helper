import re

file_path = r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _TransactionsPage constructor
old_constructor = r'''class _TransactionsPage extends StatefulWidget \{
  const _TransactionsPage\(\{
    required this\.categoryPreferences,
    required this\.filter,
    required this\.onFilterChanged,
    this\.showAppBar = false,
    this\.onParentCategorySelected,
    this\.showTypeFilter = true,
  \}\);

  final CategoryPreferencesService categoryPreferences;
  final TransactionTypeFilter filter;
  final ValueChanged<TransactionTypeFilter> onFilterChanged;
  final bool showAppBar;
  final bool showTypeFilter;
  final Future<void> Function\(
    String parentCategory,
    List<TransactionCategory> categoryOptions,
  \)\?
  onParentCategorySelected;'''

new_constructor = '''class _TransactionsPage extends StatefulWidget {
  const _TransactionsPage({
    required this.categoryPreferences,
    required this.filter,
    required this.onFilterChanged,
    this.showAppBar = false,
    this.onParentCategorySelected,
    this.showTypeFilter = true,
    this.isSettlement = false,
    this.isPayableSettlement,
    this.onAssetSelected,
  });

  final CategoryPreferencesService categoryPreferences;
  final TransactionTypeFilter filter;
  final ValueChanged<TransactionTypeFilter> onFilterChanged;
  final bool showAppBar;
  final bool showTypeFilter;
  final bool isSettlement;
  final bool? isPayableSettlement;
  final Future<void> Function(Map<String, dynamic> asset)? onAssetSelected;
  final Future<void> Function(
    String parentCategory,
    List<TransactionCategory> categoryOptions,
  )?
  onParentCategorySelected;'''

content = re.sub(old_constructor, new_constructor, content)

# 2. Add state variables to _TransactionsPageState
old_state_vars = r'''  late TransactionTypeFilter _filter;

  @override
  void initState\(\) \{'''

new_state_vars = '''  late TransactionTypeFilter _filter;
  bool _showAssets = false;
  List<Map<String, dynamic>>? _assets;

  @override
  void initState() {'''

content = re.sub(old_state_vars, new_state_vars, content)

# 3. Add asset loading
old_init = r'''  @override
  void initState\(\) \{
    super\.initState\(\);
    _filter = widget\.filter;
  \}'''

new_init = '''  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
    if (widget.isSettlement) {
      _loadAssets();
    }
  }

  Future<void> _loadAssets() async {
    final assets = await TaxDatabase.instance.fetchAssets();
    if (mounted) {
      setState(() => _assets = assets);
    }
  }'''

content = re.sub(old_init, new_init, content)

# 4. Modify SegmentedButton
old_build_body = r'''  Widget _buildBody\(\) \{
    final categories =
        TransactionCategory\.values\.where\(_isVisible\)\.toList\(\)
          \.\.sort\(\(a, b\) => a\.displayName\.compareTo\(b\.displayName\)\);

    return Column\(
      children: \[
        if \(widget\.showTypeFilter\)
          Padding\(
            padding: const EdgeInsets\.all\(16\),
            child: SizedBox\(
              width: double\.infinity,
              child: SegmentedButton<TransactionTypeFilter>\(
                segments: const \[
                  ButtonSegment\(
                    value: TransactionTypeFilter\.income,
                    label: Text\('Income'\),
                  \),
                  ButtonSegment\(
                    value: TransactionTypeFilter\.expense,
                    label: Text\('Expense'\),
                  \),
                \],
                selected: \{_filter\},
                onSelectionChanged: \(selection\) \{
                  final newFilter = selection\.first;
                  setState\((\) => _filter = newFilter);
                  widget\.onFilterChanged\(newFilter\);
                \},
              \),
            \),
          \),'''

new_build_body = '''  Widget _buildBody() {
    final categories =
        TransactionCategory.values.where(_isVisible).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Column(
      children: [
        if (widget.showTypeFilter)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: widget.isSettlement
                  ? SegmentedButton<bool>(
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
                        final newFilter = selection.first;
                        setState(() => _filter = newFilter);
                        widget.onFilterChanged(newFilter);
                      },
                    ),
            ),
          ),'''

content = re.sub(old_build_body, new_build_body, content)

# 5. Modify GridView
old_grid = r'''        Expanded\(
          child: GridView\.builder\(
            padding: const EdgeInsets\.symmetric\(horizontal: 16, vertical: 8\),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount\(
              crossAxisCount: 3,
              childAspectRatio: 0\.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            \),
            itemCount: categories\.length,
            itemBuilder: \(context, index\) \{
              final category = categories\[index\];
              return _CategoryTile\(
                category: category,
                onTap:
                    \(\) => _openParentTransaction\(
                      category\.name,
                      category\.subcategories,
                    \),
              \);
            \},
          \),
        \),'''

new_grid = '''        Expanded(
          child: _showAssets
              ? (_assets == null
                  ? const Center(child: CircularProgressIndicator())
                  : _assets!.isEmpty
                      ? const Center(child: Text('No assets found.'))
                      : ListView.builder(
                          itemCount: _assets!.length,
                          itemBuilder: (context, index) {
                            final asset = _assets![index];
                            return ListTile(
                              leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0F6B57)),
                              title: Text(asset['name']),
                              subtitle: Text('Balance: PKR ${asset['value']}'),
                              onTap: () {
                                if (widget.onAssetSelected != null) {
                                  widget.onAssetSelected!(asset);
                                }
                              },
                            );
                          },
                        ))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryTile(
                      category: category,
                      onTap:
                          () => _openParentTransaction(
                            category.name,
                            category.subcategories,
                          ),
                    );
                  },
                ),
        ),'''

content = re.sub(old_grid, new_grid, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated _TransactionsPage in dashboard_screen.dart")
