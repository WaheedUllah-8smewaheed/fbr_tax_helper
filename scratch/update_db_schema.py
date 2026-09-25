import re

# 1. Update khata_entry.dart
with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\khata\domain\entities\khata_entry.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Add fromIncome to constructor
code = code.replace('    this.isWrittenOff = false,\n  });', '    this.isWrittenOff = false,\n    this.fromIncome = false,\n  });')
# Add fromIncome field
code = code.replace('  final bool isWrittenOff;', '  final bool isWrittenOff;\n  final bool fromIncome;')
# Add to copyWith
code = code.replace('    bool? isWrittenOff,\n  }) {', '    bool? isWrittenOff,\n    bool? fromIncome,\n  }) {')
code = code.replace('      isWrittenOff: isWrittenOff ?? this.isWrittenOff,\n    );', '      isWrittenOff: isWrittenOff ?? this.isWrittenOff,\n      fromIncome: fromIncome ?? this.fromIncome,\n    );')
# Add to toMap
code = code.replace("      'isWrittenOff': isWrittenOff ? 1 : 0,\n    };", "      'isWrittenOff': isWrittenOff ? 1 : 0,\n      'fromIncome': fromIncome ? 1 : 0,\n    };")
# Add to fromMap
code = code.replace("      isWrittenOff: (map['isWrittenOff'] as int? ?? 0) == 1,\n    );", "      isWrittenOff: (map['isWrittenOff'] as int? ?? 0) == 1,\n      fromIncome: (map['fromIncome'] as int? ?? 0) == 1,\n    );")
# Add to props
code = code.replace('        isWrittenOff,\n      ];', '        isWrittenOff,\n        fromIncome,\n      ];')

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\khata\domain\entities\khata_entry.dart', 'w', encoding='utf-8') as f:
    f.write(code)

# 2. Update asset.dart
with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\assets\domain\entities\asset.dart', 'r', encoding='utf-8') as f:
    code = f.read()

code = code.replace('    required this.updatedAt,\n  });', '    required this.updatedAt,\n    this.description = \'\',\n  });')
code = code.replace('  final DateTime updatedAt;', '  final DateTime updatedAt;\n  final String description;')
code = code.replace('    DateTime? updatedAt,\n  }) {', '    DateTime? updatedAt,\n    String? description,\n  }) {')
code = code.replace('      updatedAt: updatedAt ?? this.updatedAt,\n    );', '      updatedAt: updatedAt ?? this.updatedAt,\n      description: description ?? this.description,\n    );')
code = code.replace("      'updatedAt': updatedAt.toIso8601String(),\n    };", "      'updatedAt': updatedAt.toIso8601String(),\n      'description': description,\n    };")
code = code.replace("          DateTime.now(),\n    );", "          DateTime.now(),\n      description: map['description'] as String? ?? '',\n    );")
code = code.replace('        updatedAt,\n      ];', '        updatedAt,\n        description,\n      ];')

with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\features\assets\domain\entities\asset.dart', 'w', encoding='utf-8') as f:
    f.write(code)

# 3. Update tax_database.dart
with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\core\database\tax_database.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Update version from 6 to 7
code = code.replace('version: 6,', 'version: 7,')
# Update _createDB khata_entries
code = code.replace("isWrittenOff INTEGER NOT NULL DEFAULT 0)", "isWrittenOff INTEGER NOT NULL DEFAULT 0,\n          fromIncome INTEGER NOT NULL DEFAULT 0)")
# Update _createDB assets
code = code.replace("updatedAt TEXT NOT NULL)", "updatedAt TEXT NOT NULL,\n          description TEXT NOT NULL DEFAULT '')")

# Add to _upgradeDB
upgrade_pattern = r'''    if \(oldVersion < 6\) \{
      await _addColumnIfMissing\(
        db,
        table: 'transactions',
        column: 'linkedCounterpartyOrAsset',
        definition: 'TEXT',
      \);
    \}'''
upgrade_replacement = '''    if (oldVersion < 6) {
      await _addColumnIfMissing(
        db,
        table: 'transactions',
        column: 'linkedCounterpartyOrAsset',
        definition: 'TEXT',
      );
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(
        db,
        table: 'khata_entries',
        column: 'fromIncome',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        table: 'assets',
        column: 'description',
        definition: "TEXT NOT NULL DEFAULT ''",
      );
    }'''

if 'oldVersion < 7' not in code:
    code = re.sub(upgrade_pattern, upgrade_replacement, code)
    
with open(r'd:\New Flutter Application\New-App\fbr_tax_helper\lib\core\database\tax_database.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Entities and DB schema updated!")
