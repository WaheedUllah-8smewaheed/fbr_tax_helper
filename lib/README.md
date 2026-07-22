# Source layout

The application uses a feature-first structure. Start in `features/<feature>`
when changing user-facing behavior; use `core` only for code shared by several
features.

```text
lib/
|-- core/                         Shared database, network, platform, theme,
|                                 and validation infrastructure
|-- features/
|   |-- auth/                     Login, signup, session routing, and 2FA
|   |-- backup/                   Google Drive backup and restore
|   |-- dashboard/                Authenticated app shell and dashboard
|   |-- deductions/               Deduction domain and UI
|   |-- splash/                   Application startup screen
|   |-- tax_calculator/           Tax calculation data, domain, BLoC, and UI
|   |-- transactions/             Transactions, categories, notifications,
|   |                             receipt scanning, and reports
|   `-- verification/             ATL, NTN, and CPR verification
|-- firebase_options.dart         Generated Firebase configuration
`-- main.dart                     Dependency wiring and application entry point
```

Inside a feature, use these folders when the layer is needed:

- `data/datasources`: local or remote data access
- `data/models`: serialized data models
- `data/repositories`: repository implementations
- `data/services`: external API or platform integrations
- `domain/entities`: business objects
- `domain/repositories`: repository contracts
- `domain/usecases`: business operations
- `presentation/bloc`: BLoCs, events, and states
- `presentation/pages`: full screens and routes
- `presentation/widgets`: reusable feature widgets
- `services`: feature-owned services used across multiple layers

The `test/features` tree mirrors `lib/features`, so a feature's tests can be
found at the corresponding path.
