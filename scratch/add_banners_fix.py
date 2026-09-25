import re

def insert_intro_banner(file_path, class_name, banner_code):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Insert banner method into the state class
    state_class_pattern = r'(class ' + class_name + r'State extends State<.*?>[\s\S]*?\{)'
    if not re.search(state_class_pattern, content):
        print(f"Could not find state class for {class_name} in {file_path}")
        return
    
    content = re.sub(state_class_pattern, r'\1\n' + banner_code, content)
    
    if class_name == '_ProfilePage':
        col_pattern = r'(Widget build\(BuildContext context\)\s*\{[\s\S]*?body:\s*ListView\(\s*padding:\s*const EdgeInsets\.all\(16\),\s*children:\s*\[)'
        content = re.sub(col_pattern, r'\1\n          _buildIntroCard(),\n          const SizedBox(height: 12),', content, count=1)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

profile_banner = """
  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings & Security',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Update your personal profile, secure your application, and manage data backups.',
            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14),
          ),
        ],
      ),
    );
  }
"""

insert_intro_banner(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\profile_page.dart', '_ProfilePage', profile_banner)

print("Profile Banner added!")
