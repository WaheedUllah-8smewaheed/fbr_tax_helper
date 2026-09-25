import re

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# --- 2. Add progress dialog for backup/restore ---
backup_func = r'''  Future<void> _runDriveOperation(_DriveAction action) async {
    if (_isWorking) return;
    if (action == _DriveAction.restore && !await _confirmRestore()) return;
    if (!mounted) return;

    setState(() {
      _isWorking = true;
    });'''

backup_replace = r'''  Future<void> _runDriveOperation(_DriveAction action) async {
    if (_isWorking) return;
    if (action == _DriveAction.restore && !await _confirmRestore()) return;
    if (!mounted) return;

    setState(() {
      _isWorking = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                action == _DriveAction.backup 
                    ? 'Backing up data to Google Drive...' 
                    : 'Restoring data from Google Drive...',
              ),
            ),
          ],
        ),
      ),
    );'''

code = code.replace(backup_func, backup_replace)

backup_finally = r'''      setState(() {
        _isWorking = false;
      });
    }
  }'''

backup_finally_replace = r'''      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        _isWorking = false;
      });
    }
  }'''
code = code.replace(backup_finally, backup_finally_replace)


with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\dashboard\presentation\pages\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
print("Done backup progress dialog")
