import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

security_block_pattern = r'''            const SizedBox\(height: 20\),
            Text\(
              'Security',
              style: Theme.of\(
                context,
              \).textTheme.titleLarge\?.copyWith\(fontWeight: FontWeight.w800\),
            \),
            const SizedBox\(height: 10\),
            Card\(
              child: ListTile\(
                leading: Icon\(
                  _isBiometricEnabled \? Icons.fingerprint : Icons.lock_outline,
                  color: _isBiometricEnabled \? Colors.green : Colors.teal,
                \),
                title: Text\(
                  _isBiometricEnabled
                      \? 'Fingerprint app lock enabled'
                      : 'Enable fingerprint app lock',
                \),
                subtitle: Text\(
                  !_isBiometricSupported
                      \? 'Set up biometrics or a device screen lock first'
                      : _isBiometricEnabled
                      \? 'This app requires device authentication to open.'
                      : 'Protect this app with your device security.',
                \),
                trailing: _isLoadingBiometric
                    \? const SizedBox.square\(
                        dimension: 20,
                        child: CircularProgressIndicator\(strokeWidth: 2\),
                      \)
                    : const Icon\(Icons.chevron_right\),
                onTap: _isBiometricSupported && !_isLoadingBiometric
                    \? _toggleBiometricLock
                    : null,
              \),
            \),
            const SizedBox\(height: 12\),
            const Text\(
              'When enabled, Filer Flow asks for your fingerprint, Face ID, or device screen lock on launch and after returning from the background.',
            \),'''

code = re.sub(security_block_pattern, '', code, flags=re.MULTILINE)

security_tile_code = '''
class _SecuritySettingsTile extends StatefulWidget {
  const _SecuritySettingsTile();
  @override
  State<_SecuritySettingsTile> createState() => _SecuritySettingsTileState();
}

class _SecuritySettingsTileState extends State<_SecuritySettingsTile> {
  final _biometricLock = BiometricLockService();
  bool _isLoadingBiometric = true;
  bool _isBiometricEnabled = false;
  bool _isBiometricSupported = false;

  AuthService get _authService => context.read<AuthService>();

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoadingBiometric = false);
      return;
    }
    try {
      final supported = await _biometricLock.isSupported();
      final enabled = await _biometricLock.isEnabled(userId);
      if (!mounted) return;
      setState(() {
        _isBiometricSupported = supported;
        _isBiometricEnabled = enabled;
        _isLoadingBiometric = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingBiometric = false);
    }
  }

  Future<void> _toggleBiometricLock() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null || _isLoadingBiometric) return;
    setState(() => _isLoadingBiometric = true);
    try {
      if (_isBiometricEnabled) {
        await _biometricLock.disable(userId);
      } else {
        await _biometricLock.enable(userId);
      }
      if (!mounted) return;
      final enabled = !_isBiometricEnabled;
      setState(() {
        _isBiometricEnabled = enabled;
        _isLoadingBiometric = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const FilerFlowLogo(size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  enabled
                      ? 'Fingerprint app lock enabled.'
                      : 'Fingerprint app lock disabled.',
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingBiometric = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Text(
            'Security',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A2F),
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Icon(
              _isBiometricEnabled ? Icons.fingerprint : Icons.lock_outline,
              color: _isBiometricEnabled ? Colors.green : Colors.teal,
            ),
            title: Text(
              _isBiometricEnabled
                  ? 'Fingerprint app lock enabled'
                  : 'Enable fingerprint app lock',
            ),
            subtitle: Text(
              !_isBiometricSupported
                  ? 'Set up biometrics or a device screen lock first'
                  : _isBiometricEnabled
                      ? 'This app requires device authentication to open.'
                      : 'Protect this app with your device security.',
            ),
            trailing: _isLoadingBiometric
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isBiometricSupported && !_isLoadingBiometric
                ? _toggleBiometricLock
                : null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 4, bottom: 16),
          child: Text(
            'When enabled, Filer Flow asks for your fingerprint, Face ID, or device screen lock on launch and after returning from the background.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
'''
code = code + security_tile_code

# Now add _SecuritySettingsTile() to _MorePage list view children
more_page_pattern = r'''          _MoreMenuTile\(
            icon: Icons.help_outline,
            title: 'Support',
            subtitle: 'Get help with Filer Flow',
            color: const Color\(0xFF00897B\),
            onTap: \(\) => Navigator.of\(context\).push\(
              MaterialPageRoute\(builder: \(context\) => const _SupportPage\(\)\),
            \),
          \),
        \]\),'''

more_page_replace = r'''          _MoreMenuTile(
            icon: Icons.help_outline,
            title: 'Support',
            subtitle: 'Get help with Filer Flow',
            color: const Color(0xFF00897B),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const _SupportPage()),
            ),
          ),
        ]),
        const _SecuritySettingsTile(),'''

code = re.sub(more_page_pattern, more_page_replace, code)

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Done Security refactor")
