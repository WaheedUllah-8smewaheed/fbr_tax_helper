part of 'dashboard_screen.dart';

class _MorePage extends StatefulWidget {
  const _MorePage({this.categoryPreferences});

  final CategoryPreferencesService? categoryPreferences;

  @override
  State<_MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<_MorePage> {
  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A2F),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (item) =>
                        SizedBox(width: itemWidth, height: 145, child: item),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 96.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      children: [
        Text(
          'More Tools',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E3A2F),
          ),
        ),
        _buildSection('Financials', [
          _MoreMenuTile(
            icon: Icons.calculate_outlined,
            title: 'Calculators',
            subtitle: 'Tax, percentage and zakat tools',
            color: const Color(0xFF0F6B57),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const _CalculatorsPage()),
            ),
          ),
          if (widget.categoryPreferences != null)
            _MoreMenuTile(
              icon: Icons.compare_arrows_rounded,
              title: 'Comparison',
              subtitle: 'Compare year-over-year stats',
              color: const Color(0xFF3949AB),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _ComparisonDashboardPage(
                    categoryPreferences: widget.categoryPreferences!,
                  ),
                ),
              ),
            ),
        ]),
        _buildSection('Backup & Restore', [
          const _DriveSyncButton(asListTile: true, action: _DriveAction.backup),
          const _DriveSyncButton(
            asListTile: true,
            action: _DriveAction.restore,
          ),
        ]),
        _buildSection('About & Support', [
          _MoreMenuTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'About Filer Flow',
            color: const Color(0xFF6D4C41),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const _AboutPage())),
          ),
          _MoreMenuTile(
            icon: Icons.help_outline,
            title: 'Support',
            subtitle: 'Get help with Filer Flow',
            color: const Color(0xFF00897B),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const _SupportPage()),
            ),
          ),
        ]),
      ],
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculatorsPage extends StatelessWidget {
  const _CalculatorsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculators')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          _MoreMenuTile(
            icon: Icons.account_balance_outlined,
            title: 'Tax Calculator',
            subtitle: 'Salary and business tax',
            color: const Color(0xFF0F6B57),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const TaxCalculatorScreen(appBarTitle: 'Tax Calculator'),
              ),
            ),
          ),
          _MoreMenuTile(
            icon: Icons.percent_rounded,
            title: 'Percentage Calculator',
            subtitle: 'Calculate percentages quickly',
            color: const Color(0xFF3949AB),
            onTap: () => _showComingSoon(context, 'Percentage Calculator'),
          ),
          _MoreMenuTile(
            icon: Icons.volunteer_activism_outlined,
            title: 'Zakat Calculator',
            subtitle: 'Calculate zakat on your wealth',
            color: const Color(0xFF2E7D32),
            onTap: () => _showComingSoon(context, 'Zakat Calculator'),
          ),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title will be available soon.')));
  }
}

class _SupportPage extends StatelessWidget {
  const _SupportPage();

  static const _supportEmail = 'kpxdigital@gmail.com';

  Future<void> _contactSupport(BuildContext context) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      //queryParameters: const {'subject': 'Support related to Filer Flow'},
      query: 'subject=${Uri.encodeComponent('Support related to Filer Flow')}',
    );

    final opened = await launchUrl(emailUri);
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Could not open an email application.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Support')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewPadding = MediaQuery.viewPaddingOf(context);
          final isCompact = constraints.maxHeight < 650;
          final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
          final bottomPadding = viewPadding.bottom + 24;
          final topPadding = isCompact ? 16.0 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding + viewPadding.left,
              topPadding,
              horizontalPadding + viewPadding.right,
              bottomPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - topPadding - bottomPadding,
                ),
              ),
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/kpxdigitalgrey.png',
                            width: isCompact ? 130 : 155,
                            height: isCompact ? 44 : 54,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: isCompact ? 14 : 20),
                        Text(
                          'How can we help?',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Questions or problems with Filer Flow? Send our '
                          'support team a message and we will get back to you.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                        SizedBox(height: isCompact ? 18 : 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.mintSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Email support',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    SelectableText(
                                      _supportEmail,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(height: isCompact ? 20 : 32),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: () => _contactSupport(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.send_outlined, size: 19),
                            label: const Text(
                              'Contact support',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  static const _features = [
    'Visual dashboard with income, expense and balance overview',
    'Quick transaction entry — manually or via receipt scan',
    'Customizable income and expense categories',
    'Built-in tax calculator for Salary, PSEB Export and WHT',
    'Secure backup and restore via Google Drive',
    'Fingerprint-secured profile with 2FA',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('About Filer Flow')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewPadding = MediaQuery.viewPaddingOf(context);
          final isCompact = constraints.maxHeight < 720;
          final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
          final verticalPadding = isCompact ? 14.0 : 22.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding + viewPadding.left,
              verticalPadding,
              horizontalPadding + viewPadding.right,
              viewPadding.bottom + verticalPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/kpxdigitalgrey.png',
                        width: isCompact ? 120 : 145,
                        height: isCompact ? 42 : 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 14),
                    Text(
                      'Personal finance and tax tools in one secure place.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    SizedBox(height: isCompact ? 16 : 22),
                    Text(
                      'Key features',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, contentConstraints) {
                        final columns = contentConstraints.maxWidth >= 540
                            ? 2
                            : 1;
                        final itemWidth = columns == 2
                            ? (contentConstraints.maxWidth - 20) / 2
                            : contentConstraints.maxWidth;

                        return Wrap(
                          spacing: 20,
                          runSpacing: isCompact ? 6 : 8,
                          children: [
                            for (final feature in _features)
                              SizedBox(
                                width: itemWidth,
                                child: _AboutFeature(
                                  label: feature,
                                  compact: isCompact,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: isCompact ? 12 : 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mintSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 21,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your data stays on your device. You decide when '
                              'and where it is backed up.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.primaryDark,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 12 : 18),
                    Text.rich(
                      TextSpan(
                        text: 'Version 1.0  |  Developed by ',
                        children: [
                          TextSpan(
                            text: 'KPX Digital',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: compact ? 16 : 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _CategorySettingsPage extends StatelessWidget {
  const _CategorySettingsPage({required this.categoryPreferences});

  final CategoryPreferencesService categoryPreferences;

  Future<void> _updateEnabled(
    BuildContext context,
    String categoryName,
    bool enabled,
  ) async {
    try {
      await categoryPreferences.setEnabled(categoryName, enabled: enabled);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save category setting: $error')),
        );
    }
  }

  Future<void> _updateParentMode(
    BuildContext context,
    String parentName,
    CategoryMode mode,
  ) async {
    try {
      await categoryPreferences.setParentMode(parentName, mode: mode);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save category setting: $error')),
        );
    }
  }

  Future<void> _updateParentEnabled(
    BuildContext context,
    String parentName,
    bool enabled,
  ) async {
    try {
      await categoryPreferences.setParentEnabled(parentName, enabled: enabled);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not save category setting: $error')),
        );
    }
  }

  Future<void> _deleteSubcategory(
    BuildContext context,
    String parentName,
    String categoryName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Subcategory'),
        content: Text(
          'Are you sure you want to delete "$categoryName" from $parentName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await categoryPreferences.removeSubcategory(
          parentName: parentName,
          categoryName: categoryName,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Subcategory "$categoryName" removed.')),
          );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Could not remove subcategory: $error')),
          );
      }
    }
  }

  Future<void> _showAddSubcategoryDialog(
    BuildContext context,
    String parentName,
  ) async {
    final controller = TextEditingController();
    final parentMode = categoryPreferences.modeForParent(parentName);
    final isDual = parentMode == CategoryMode.both;
    var isExpense = parentMode == CategoryMode.expense;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Add Subcategory to $parentName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Subcategory name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (isDual) ...[
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Income')),
                        ButtonSegment(value: true, label: Text('Expense')),
                      ],
                      selected: {isExpense},
                      onSelectionChanged: (selection) {
                        setDialogState(() {
                          isExpense = selection.first;
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final name = controller.text.trim();
      try {
        await categoryPreferences.addSubcategory(
          parentName: parentName,
          categoryName: name,
          isExpense: isDual ? isExpense : (parentMode == CategoryMode.expense),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Subcategory "$name" added to $parentName.'),
            ),
          );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Could not add subcategory: $error')),
          );
      }
    }
  }

  IconData _iconForSuperCategory(String name) {
    return switch (name) {
      'Money In' => Icons.account_balance_wallet_outlined,
      'Home' => Icons.home_outlined,
      'Travel' => Icons.directions_car_outlined,
      'Food' => Icons.restaurant_outlined,
      'Shopping' => Icons.shopping_bag_outlined,
      'Health' => Icons.favorite_outline,
      'Education' => Icons.school_outlined,
      'Personal Care' => Icons.spa_outlined,
      'Entertainment' => Icons.tv_outlined,
      'Gifts' => Icons.card_giftcard_outlined,
      'Charity' => Icons.volunteer_activism_outlined,
      'Taxes' => Icons.request_quote_outlined,
      'Banking' => Icons.account_balance_outlined,
      'Commitments' => Icons.assignment_turned_in_outlined,
      'Commitements' => Icons.assignment_turned_in_outlined,
      'Others' => Icons.inventory_2_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: categoryPreferences,
      builder: (context, _) {
        if (categoryPreferences.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final hierarchy = categoryPreferences.hierarchy;
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 96.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          children: [
            Text(
              'Category Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Toggle a category to show or hide all its items, customize subcategories, or add new ones.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (categoryPreferences.loadError != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Saved category settings could not be loaded. Default classifications are currently shown.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ...hierarchy.entries.map((superCategory) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: Icon(_iconForSuperCategory(superCategory.key)),
                    title: Text(
                      superCategory.key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    children: [
                      for (final parent in superCategory.value.entries)
                        ExpansionTile(
                          tilePadding: const EdgeInsets.only(
                            left: 28,
                            right: 16,
                          ),
                          childrenPadding: EdgeInsets.zero,
                          leading: Icon(
                            _getIconForCategory(parent.key),
                            size: 21,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  parent.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: categoryPreferences.isParentEnabled(
                                  parent.key,
                                ),
                                onChanged: (enabled) => _updateParentEnabled(
                                  context,
                                  parent.key,
                                  enabled,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                              child: SegmentedButton<CategoryMode>(
                                expandedInsets: EdgeInsets.zero,
                                showSelectedIcon: false,
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: CategoryMode.income,
                                    label: Text('Income'),
                                  ),
                                  ButtonSegment(
                                    value: CategoryMode.expense,
                                    label: Text('Expense'),
                                  ),
                                  ButtonSegment(
                                    value: CategoryMode.both,
                                    label: Text('Both'),
                                  ),
                                ],
                                selected: {
                                  categoryPreferences.modeForParent(parent.key),
                                },
                                onSelectionChanged: (selection) =>
                                    _updateParentMode(
                                      context,
                                      parent.key,
                                      selection.first,
                                    ),
                              ),
                            ),
                            for (final category in parent.value)
                              SwitchListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 48,
                                  right: 16,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(category.name)),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: Colors.red.shade400,
                                      ),
                                      tooltip: 'Delete subcategory',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _deleteSubcategory(
                                        context,
                                        parent.key,
                                        category.name,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  categoryPreferences.isDualMode(category.name)
                                      ? 'Income or Expense'
                                      : categoryPreferences.isExpense(
                                          category.name,
                                        )
                                      ? 'Expense'
                                      : 'Income',
                                ),
                                value: categoryPreferences.isEnabled(
                                  category.name,
                                ),
                                onChanged: (enabled) => _updateEnabled(
                                  context,
                                  category.name,
                                  enabled,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(48, 4, 16, 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(
                                    'Add subcategory to ${parent.key}',
                                  ),
                                  onPressed: () => _showAddSubcategoryDialog(
                                    context,
                                    parent.key,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

