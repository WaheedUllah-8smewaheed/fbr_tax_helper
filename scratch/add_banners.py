import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Profile Page Banner
profile_pattern = r'''      body: SafeArea\(
        top: false,
        child: ListView\(
          padding: const EdgeInsets\.all\(16\),
          children: \['''

profile_banner = '''      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.forest, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings & Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your account details, biometric security, and app preferences.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),'''

code = code.replace(profile_pattern, profile_banner)


# 2. More Page Banner
more_pattern = r'''    return ListView\(
      padding: EdgeInsets\.fromLTRB\(16, 8, 16, bottomPadding\),
      children: \[
        Text\(
          'More Tools',
          style: Theme\.of\(context\)\.textTheme\.headlineSmall\?\.copyWith\(
            fontWeight: FontWeight\.w900,
            color: const Color\(0xFF1E3A2F\),
          \),
        \),'''

more_banner = '''    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.forest, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'More Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Access additional financial calculators, insights, planners, and utilities.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),'''

code = code.replace(more_pattern, more_banner)


# 3. View All Transactions Banner
all_tx_pattern = r'''            return ListView\(
              padding: EdgeInsets\.fromLTRB\(16, 16, 16, bottomPadding\),
              children: \['''

all_tx_banner = '''            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.forest, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'All Transactions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'View, search, and filter your complete transaction history by date and category.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),'''

# Wait, `all_tx_pattern` matches line 835 for _AllTransactionsPage! But there is another `ListView` for _TransactionsPage at line 431!
# Wait, I can use `re.sub` for AllTransactionsPage. But let's check line 835 specifically.
# Let's ensure I only replace the exact one in _AllTransactionsPage.
code = re.sub(
    r'(\s+final categoryMode = resolveCategoryMode\([^}]+\s+final bottomPadding = MediaQuery\.paddingOf\(context\)\.bottom \+ 90\.0;\s+return ListView\(\s+padding: EdgeInsets\.fromLTRB\(16, 16, 16, bottomPadding\),\s+children: \[)',
    r'\1\n                Container(\n                  margin: const EdgeInsets.only(bottom: 16),\n                  padding: const EdgeInsets.all(18),\n                  decoration: BoxDecoration(\n                    gradient: const LinearGradient(\n                      colors: [AppColors.forest, AppColors.primary],\n                      begin: Alignment.topLeft,\n                      end: Alignment.bottomRight,\n                    ),\n                    borderRadius: BorderRadius.circular(20),\n                    boxShadow: [\n                      BoxShadow(\n                        color: AppColors.primary.withValues(alpha: 0.2),\n                        blurRadius: 12,\n                        offset: const Offset(0, 6),\n                      ),\n                    ],\n                  ),\n                  child: Column(\n                    crossAxisAlignment: CrossAxisAlignment.start,\n                    children: [\n                      const Text(\n                        \'All Transactions\',\n                        style: TextStyle(\n                          color: Colors.white,\n                          fontSize: 18,\n                          fontWeight: FontWeight.bold,\n                        ),\n                      ),\n                      const SizedBox(height: 8),\n                      Text(\n                        \'View, search, and filter your complete transaction history by date and category.\',\n                        style: TextStyle(\n                          color: Colors.white.withValues(alpha: 0.9),\n                          fontSize: 13,\n                        ),\n                      ),\n                    ],\n                  ),\n                ),',
    code
)


with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Script completed!")
