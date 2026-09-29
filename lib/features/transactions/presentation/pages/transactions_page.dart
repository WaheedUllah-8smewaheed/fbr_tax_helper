import 'dart:async';
import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';

import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';

import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:flutter/material.dart';
import 'transaction_widgets.dart';
import 'all_transactions_page.dart';

enum TransactionTypeFilter { income, expense }

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
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
  onParentCategorySelected;

  @override
  State<TransactionsPage> createState() => TransactionsPageState();
}

class TransactionsPageState extends State<TransactionsPage> {
  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Record Transaction',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a category below to record a new income or expense transaction.',
            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14),
          ),
        ],
      ),
    );
  }

  late TransactionTypeFilter _filter;
  bool _showAssets = false;
  List<Map<String, dynamic>>? _assets;

  @override
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
  }

  @override
  void didUpdateWidget(covariant TransactionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _filter = widget.filter;
    }
  }

  Future<void> _openParentTransaction(
    String parentCategory,
    List<TransactionCategory> categoryOptions,
  ) async {
    final onParentCategorySelected = widget.onParentCategorySelected;
    if (onParentCategorySelected != null) {
      return onParentCategorySelected(parentCategory, categoryOptions);
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          parentCategory: parentCategory,
          categoryOptions: categoryOptions,
          categoryPreferences: widget.categoryPreferences,
          initialIsExpense: _filter == TransactionTypeFilter.expense
              ? true
              : (_filter == TransactionTypeFilter.income
                    ? false
                    : widget.categoryPreferences.isExpense(parentCategory)),
          onViewCategoryHistory: (category, {required includeSubcategories}) {
            Navigator.of(this.context).push(
              MaterialPageRoute(
                builder: (context) => AllTransactionsPage(
                  categoryPreferences: widget.categoryPreferences,
                  initialCategory: category,
                  initialCategoryIncludesChildren: includeSubcategories,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isVisible(TransactionCategory category) {
    if (!widget.categoryPreferences.isEnabled(category.name)) return false;
    return switch (_filter) {
      TransactionTypeFilter.income =>
        widget.categoryPreferences.shouldShowCategoryInSection(
          categoryName: category.name,
          isExpenseSection: false,
        ),
      TransactionTypeFilter.expense =>
        widget.categoryPreferences.shouldShowCategoryInSection(
          categoryName: category.name,
          isExpenseSection: true,
        ),
    };
  }

  List<_TransactionCategoryCardData> _visibleCategoryCards() {
    return widget.categoryPreferences.hierarchy.entries.expand((superCategory) {
      return superCategory.value.entries
          .map(
            (parent) => _TransactionCategoryCardData(
              groupName: superCategory.key,
              categoryName: parent.key,
              options: parent.value.where(_isVisible).toList(),
            ),
          )
          .where((card) => card.options.isNotEmpty);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                            label: Text(
                              widget.isPayableSettlement == true
                                  ? 'Expense'
                                  : 'Income',
                            ),
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
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Color(0xFF0F6B57),
                                    ),
                                    title: Text(asset['name']),
                                    subtitle: Text(
                                      'Balance: PKR ${asset['value']}',
                                    ),
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: constraints.maxWidth < 360
                                    ? 1.12
                                    : 1.3,
                              ),
                          itemBuilder: (context, index) {
                            final card = categoryCards[index];
                            return _AnimatedTransactionCategoryCard(
                              key: ValueKey(
                                '${_filter.name}-${card.categoryName}',
                              ),
                              data: card,
                              index: index,
                              onTap: () => _openParentTransaction(
                                card.categoryName,
                                card.options,
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
  }
}

class _TransactionCategoryCardData {
  const _TransactionCategoryCardData({
    required this.groupName,
    required this.categoryName,
    required this.options,
  });

  final String groupName;
  final String categoryName;
  final List<TransactionCategory> options;
}

class _AnimatedTransactionCategoryCard extends StatefulWidget {
  const _AnimatedTransactionCategoryCard({
    super.key,
    required this.data,
    required this.index,
    required this.onTap,
  });

  final _TransactionCategoryCardData data;
  final int index;
  final VoidCallback onTap;

  @override
  State<_AnimatedTransactionCategoryCard> createState() =>
      _AnimatedTransactionCategoryCardState();
}

class _AnimatedTransactionCategoryCardState
    extends State<_AnimatedTransactionCategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = getColorForCategory(widget.data.categoryName);
    final accent = HSLColor.fromColor(
      color,
    ).withHue((HSLColor.fromColor(color).hue + 28) % 360).toColor();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (widget.index % 6) * 45),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: _pressed ? 0.24 : 0.17),
                accent.withValues(alpha: _pressed ? 0.18 : 0.09),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _pressed ? 0.12 : 0.2),
                blurRadius: _pressed ? 7 : 14,
                offset: Offset(0, _pressed ? 3 : 7),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: Stack(
                children: [
                  Positioned(
                    right: -18,
                    top: -20,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 43,
                              height: 43,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, accent],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                getIconForCategory(widget.data.categoryName),
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_outward_rounded,
                              size: 20,
                              color: color,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          widget.data.groupName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.data.categoryName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
