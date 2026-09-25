import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Remove from _ProfilePageState
to_remove_state = r'''  final _biometricLock = BiometricLockService();

  bool _isLoadingBiometric = true;
  bool _isBiometricEnabled = false;
  bool _isBiometricSupported = false;'''
code = code.replace(to_remove_state, '')

to_remove_init = r'''    _loadBiometricStatus();'''
code = code.replace(to_remove_init, '')

load_biometric_pattern = r'''  Future<void> _loadBiometricStatus\(\).*?\}\s*\}'''
code = re.sub(load_biometric_pattern, '', code, flags=re.DOTALL | re.MULTILINE)

toggle_biometric_pattern = r'''  Future<void> _toggleBiometricLock\(\).*?\}\s*\}'''
code = re.sub(toggle_biometric_pattern, '', code, flags=re.DOTALL | re.MULTILINE)

security_widget_pattern = r'''            const SizedBox\(height: 20\);\s*Text\(\s*'Security',.*?\),\s*const Padding\(\s*padding: EdgeInsets\.only\(left: 4, top: 4\),\s*child: Text\(\s*'When enabled.*?,\s*\),\s*\),'''
code = re.sub(security_widget_pattern, '', code, flags=re.DOTALL | re.MULTILINE)


with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print("Done removing from ProfilePage")
