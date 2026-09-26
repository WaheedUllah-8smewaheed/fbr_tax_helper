# Filer Flow — Smart FBR Tax Helper & Financial Vault 🇵🇰

**Filer Flow** is an all-in-one personal finance, tax estimation, and expense tracking application tailored for Pakistani taxpayers, freelancers, business owners, and salaried professionals. It bridges daily bookkeeping with Federal Board of Revenue (FBR) tax compliance—allowing users to log income and expenses, scan receipts using on-device OCR, compute exact income tax liabilities across multiple fiscal years (2015-16 to 2026-27), verify Active Taxpayer List (ATL) status, and backup data securely to their private Google Drive.

> 📖 **Looking for a non-technical end-user guide?** Check out the [**End-User Operating Manual (USER_MANUAL.md)**](USER_MANUAL.md).

---

## 📑 Table of Contents
1. [Key Capabilities](#-key-capabilities)
2. [Application Architecture](#-application-architecture)
3. [Feature Breakdown & User Manual](#-feature-breakdown--user-manual)
   - [1. Authentication, Onboarding & Security](#1-authentication-onboarding--security)
   - [2. Interactive Financial Dashboard](#2-interactive-financial-dashboard)
   - [3. Transaction Logging & AI Receipt Scanner](#3-transaction-logging--ai-receipt-scanner)
   - [4. Category Preferences & Hierarchy](#4-category-preferences--hierarchy)
   - [5. FBR Income Tax Calculator](#5-fbr-income-tax-calculator)
   - [6. Tax Deductions & Adjustable Withholding Taxes](#6-tax-deductions--adjustable-withholding-taxes)
   - [7. FBR Live Verification Tools (ATL, NTN, CPR)](#7-fbr-live-verification-tools-atl-ntn-cpr)
   - [8. Cloud Backup & Cross-Device Restore](#8-cloud-backup--cross-device-restore)
   - [9. PDF Statement & Report Generation](#9-pdf-statement--report-generation)
4. [Security & Privacy Model](#-security--privacy-model)
5. [Developer Guide & Getting Started](#-developer-guide--getting-started)
   - [Prerequisites](#prerequisites)
   - [Running the App](#running-the-app)
   - [Testing & Code Quality](#testing--code-quality)
   - [Building Release Artifacts](#building-release-artifacts)
6. [Project File Structure](#-project-file-structure)

---

## 🚀 Key Capabilities

- **Zero-Friction Tax Estimation:** Accurate income tax computation according to official FBR progressive slabs from Tax Year 2015-16 through 2026-27 for Salaried, Business, and AOP taxpayers.
- **Smart Spending Donut & Visual KPI:** Live visual breakdown of expenses vs. remaining balance, top categories, monthly comparisons, and net surplus/deficit indicators.
- **On-Device AI Receipt Scanner:** Extract merchant details, dates, and amounts directly from physical receipts via Google ML Kit Text Recognition.
- **Customizable 3-Level Categories:** Flexible income/expense categorization with dual-mode support (e.g. Gifts Given/Received) and custom subcategory creation.
- **FBR Verification Suite:** Instant in-app status lookup for Active Taxpayer List (ATL), National Tax Number (NTN), and Computerized Payment Receipts (CPR).
- **Offline-First SQLite Architecture:** Fast local SQLite database with full offline functionality.
- **Bank-Grade Device Security:** Biometric fingerprint/Face ID app lock and TOTP two-factor authentication (Google Authenticator / Microsoft Authenticator).
- **Private Cloud Sync:** Encrypted backup to the user's private Google Drive AppData folder—no third-party servers storing financial data.

---

## 🏗️ Application Architecture

Filer Flow follows **Clean Architecture** principles and a **Feature-First** structure:

```
lib/
├── core/                  # Shared foundations (database, network, platform, theme, validation)
│   ├── database/          # SQLite singleton (TaxDatabase) & schema migrations
│   ├── network/           # Dio HTTP client, interceptors, and exception handling
│   ├── platform/          # Cross-platform file paths and storage abstractions
│   ├── theme/             # Theme tokens, emerald/green color palettes, and typography
│   ├── validation/        # Pakistani CNIC, NTN, and CPR format validators
│   └── widgets/           # Global reusable UI widgets (Brand logo, custom buttons)
│
├── features/              # Feature modules (Domain, Data, Presentation)
│   ├── auth/              # Firebase Auth, Google Sign-In, Biometric Lock, TOTP 2FA
│   ├── backup/            # Google Drive API backup and restore orchestrator
│   ├── dashboard/         # Main navigation shell, spending donut panel, KPI cards, filters
│   ├── deductions/        # Adjustable tax credits (Mobile, electricity, internet, vehicle)
│   ├── splash/            # Animated branding launch screen
│   ├── tax_calculator/    # Official FBR tax slab engine, historical tax profiles, BLoC
│   ├── transactions/      # Income/Expense tracking, categories, OCR scanner, PDF exports
│   └── verification/      # FBR ATL, NTN, and CPR live status verification
│
├── firebase_options.dart  # Firebase platform configuration
└── main.dart              # Application bootstrap & dependency injection
```

### State Management
State is managed using **BLoC (Business Logic Component)** (`flutter_bloc`), separating business logic from UI presentation:
- `TaxCalculatorBloc`: Reactive tax calculation, slab switching, and deduction updates.
- `LoginBloc` & `SignupBloc`: Authentication flows, error mappings, and credential validations.
- `DeductionsBloc`: Handling adjustable withholding tax values.
- `VerificationBloc`: Asynchronous FBR verification API querying and error handling.

---

## 📖 Feature Breakdown & User Manual

### 1. Authentication, Onboarding & Security

#### Guest Access (Public Mode)
- New users can explore the app and calculate taxes immediately from the Login page without creating an account via the **"Explore Calculator as Guest"** button.

#### Sign Up & Login
- **Email & Password:** Secure sign-up with client-side password strength validation and email format verification.
- **Google Sign-In:** One-tap sign-in using existing Google credentials.
- **Email Verification:** Account profile provides on-demand verification link dispatching.

#### Biometric App Lock
- Supports Fingerprint, Face ID, and Device Lock (`local_auth`).
- Configurable directly from **Profile > Security**. When enabled, navigating away or placing the app in the background locks access until biometric authentication succeeds.

#### Two-Factor Authentication (TOTP 2FA)
- Enterprise-grade security compatible with Google Authenticator, Microsoft Authenticator, and Authy.
- Scans QR codes or copies manual setup keys directly into any standard authenticator app.
- Protects login sessions against unauthorized credential access.

#### Account Lifecycle Management
- **Password Reset:** Generates a secure Firebase reset email.
- **Change Email:** Requests email update with re-authentication confirmation.
- **Remove Account:** Permanently purges the Firebase user account and deletes all local SQLite records, cached receipt images, biometric flags, and secure preferences from the device.

---

### 2. Interactive Financial Dashboard

The Dashboard acts as your central command center:

- **Dual Period Filters:**
  - **Financial Year Filter:** Filter data by fiscal years (e.g. `2025-26`, `2024-25`, or `All Years`).
  - **Month Filter:** Focus on a single month (e.g. `September`) or select `All Months` for a whole-year summary.
- **Unified Spending Donut Panel (`Expenses vs Balance`):**
  - **Green Arc:** Visual share of remaining net balance. Displays percentage label directly inside the slice.
  - **Red Arc:** Visual share of spent expenses with percentage label inside the slice.
  - **Center Hole Metric:** Displays **Net Balance** in prominent bold green (or bold red if in deficit).
  - **Quick Metric Chips:**
    - **Left Chip:** Net Surplus / Net Deficit with remaining balance percentage.
    - **Right Chip:** Total Spent with expense-to-income percentage.
- **Top Spending Categories Breakdown:**
  - Ranked bar and list views of highest expense categories.
  - Tapping any category navigates directly into filtered transaction records.
- **Income vs Expenses Comparison:**
  - Visual periodic bar trends comparing cash inflow against outflow over time.

---

### 3. Transaction Logging & AI Receipt Scanner

#### Adding a Transaction
1. Tap the **"+" (Add)** button from the navigation bar or dashboard.
2. Select **Expense** or **Income**.
3. Enter the **Amount (PKR)** and **Title**.
4. Choose the transaction **Category** and subcategory.
5. Optionally record the **Beneficiary / Merchant** and **Purpose / Note**.
6. Set the date (defaults to today).
7. Tap **Save Transaction**.

#### On-Device AI Receipt Scanner
- Tap the **Camera Icon** when adding a transaction.
- Take a photo of your paper receipt or upload an image from the gallery.
- On-device **Google ML Kit Text Recognition** parses:
  - Total bill/receipt amount.
  - Store/vendor name.
  - Transaction date.
- The parsed details automatically populate the transaction form for quick confirmation.
- Receipt images are compressed and stored locally in the app's private documents directory, viewable anytime in transaction details.

---

### 4. Category Preferences & Hierarchy

Filer Flow organizes expenses into a realistic 3-tier hierarchy:

- **Level 1: Super Categories** (e.g., Living Expenses, Commitments, Discretionary, Savings & Investments).
- **Level 2: Parent Categories** (e.g., Home Bills, Groceries, Education, Travel, Healthcare, Investments).
- **Level 3: Subcategories** (e.g., Electricity, Gas, Mobile, Fuel, Dining Out, School Fee).

#### Category Customization:
- **Toggle Visibility:** Hide categories you don't use to keep forms clean.
- **Add Custom Subcategories:** Create your own specialized tags under any parent category.
- **Dual-Mode Categories:** Categories like "Gifts" or "Commitments" can handle both incoming funds and outgoing payments.

---

### 5. FBR Income Tax Calculator

Designed specifically according to Pakistan's Federal Board of Revenue tax laws:

#### Supported Tax Years:
- Tax Year 2026-27 (Current/Upcoming)
- Tax Year 2025-26
- Historical tax years from 2015-16 to 2024-25.

#### Taxpayer Types:
- **Salaried:** Applicable when salary income constitutes 75% or more of total taxable income.
- **Non-Salaried (Business / Sole Proprietor):** Standard business individual tax slabs.
- **AOP / Other:** Association of Persons tax rates.

#### Tax Engine Capabilities:
- **Monthly & Annual Conversion:** Enter monthly income or annual gross revenue—the engine synchronizes both instantly.
- **Progressive Slab Breakdown:** Shows base fixed tax plus marginal percentage rate on amounts exceeding the lower threshold.
- **High-Income Surcharge:** Automatically applies the 10% super surcharge for taxable incomes exceeding PKR 10,000,000 where mandated.
- **Net Effective Rate:** Computes exact effective tax percentage against total earnings.
- **Instant Reset:** Clear inputs and refresh calculations with a single tap.

---

### 6. Tax Deductions & Adjustable Withholding Taxes

Under the Pakistani Income Tax Ordinance, taxes withheld on utilities, mobile top-ups, and vehicle tokens can be adjusted against your final tax liability:

- **Mobile Recharge Withholding Tax (Section 236):** Adjustable advance income tax deducted from mobile balance cards and postpaid bills.
- **Electricity Bill Advance Tax (Section 235):** Withholding tax applied on residential and commercial electric bills above statutory thresholds.
- **Internet / Broadband Tax:** Advance tax collected on internet service subscriptions.
- **Vehicle Token & Registration Tax (Section 231B / 234):** Motor vehicle advance tax paid during annual token renewals.

Tapping **"Deductions & Adjustments"** allows entering these annual paid withholding taxes, which directly reduce your payable tax figure or increase your tax refund claim.

---

### 7. FBR Live Verification Tools (ATL, NTN, CPR)

Located under the **Verification** section:

1. **Active Taxpayer List (ATL) Status:**
   - Enter your 13-digit CNIC (`XXXXX-XXXXXXX-X`).
   - Checks whether the taxpayer is actively on the ATL list (determining whether 100% higher withholding tax rates apply).
2. **NTN Verification:**
   - Verify registered business names, registration dates, and jurisdiction details associated with an NTN or CNIC.
3. **CPR (Computerized Payment Receipt) Tracker:**
   - Verify CPR numbers issued for tax challans deposited into State Bank of Pakistan / National Bank of Pakistan branches.

---

### 8. Cloud Backup & Cross-Device Restore

Filer Flow safeguards your privacy: **No financial data is ever stored on third-party company servers.**

#### Google Drive AppData Sync:
- Backups are written directly to your personal Google Drive account in an isolated `AppData` folder inaccessible to other apps.
- **What is backed up:**
  - The complete SQLite database (`fbr_tax_vault.db`).
  - All attached physical receipt images.
  - User category customizations and profile settings.
- **Cross-Device Restoration:**
  - Sign in on a new phone with the same Google Drive account and tap **Restore**.
  - The engine verifies ownership matching, unzips files, restores database integrity, and links receipt images automatically.

---

### 9. PDF Statement & Report Generation

Export your financial records for tax filing, loan applications, or accountant reviews:

- **Print / Export Filtered Transactions:** Generates high-resolution, formatted PDF transaction ledgers matching your selected financial year or month filter.
- **Period Comparison Report:** Compares two distinct fiscal years or calendar months side-by-side to highlight spending variances and savings trends.
- Built using the native `pdf` and `printing` engines—ready for direct wireless printing or WhatsApp/Email sharing.

---

## 🔐 Security & Privacy Model

| Layer | Implementation |
| :--- | :--- |
| **Local Storage** | Encrypted SQLite database (`sqflite`) stored within private app sandboxes. |
| **Sensitive Tokens** | Keystore (Android) and Keychain (iOS) via `flutter_secure_storage`. |
| **Authentication** | Firebase Authentication with mandatory password confirmation for sensitive operations. |
| **Two-Factor Auth** | Standard RFC 6238 TOTP algorithm supported across all mobile platforms. |
| **Biometric Layer** | Native hardware biometric prompts (`local_auth`) with cryptographic challenge binding. |
| **Cloud Backups** | Restricted OAuth 2.0 `drive.appdata` scope; files remain exclusively in your Google Drive. |

---

## 💻 Developer Guide & Getting Started

### Prerequisites
- **Flutter SDK:** `^3.11.5` or later
- **Dart SDK:** `^3.11.0`
- **Android Studio / Xcode** for mobile builds
- **Java:** JDK 17 (recommended for modern Android Gradle plugin)

### Running the App

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd fbr_tax_helper
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run debug mode:**
   ```bash
   flutter run
   ```

### Testing & Code Quality

- **Run Static Analysis:**
  ```bash
  dart analyze
  ```
- **Execute All Unit & Widget Tests:**
  ```bash
  flutter test
  ```
- **Run Specific Test Suites:**
  ```bash
  # Tax Calculation tests
  flutter test test/features/tax_calculator/domain/usecases/calculate_tax_liability_test.dart

  # Dashboard & Spending Summary tests
  flutter test test/features/dashboard/presentation/pages/dashboard_redesign_test.dart

  # Category Preferences tests
  flutter test test/features/transactions/services/category_preferences_service_test.dart
  ```

### Building Release Artifacts

To generate optimized, architecture-specific Android APKs:
```bash
flutter build apk --release --split-per-abi
```
Generated APKs will be output to:
- `build/app/outputs/apk/release/app-arm64-v8a-release.apk`
- `build/app/outputs/apk/release/app-armeabi-v7a-release.apk`
- `build/app/outputs/apk/release/app-x86_64-release.apk`

---

## 🗂️ Project File Structure

```text
fbr_tax_helper/
├── android/                         # Native Android Gradle configuration
├── assets/                          # App logos, brand marks, and splash assets
├── ios/                             # Native iOS Xcode workspace & schemes
├── lib/
│   ├── core/                        # Shared infrastructure
│   │   ├── database/tax_database.dart
│   │   ├── network/dio_client.dart
│   │   ├── platform/app_storage.dart
│   │   ├── theme/app_theme.dart
│   │   └── validation/fbr_validators.dart
│   ├── features/
│   │   ├── auth/                    # Authentication, 2FA & Biometric lock
│   │   ├── backup/                  # Google Drive sync service
│   │   ├── dashboard/               # Main dashboard UI, Donut chart, KPI cards
│   │   ├── deductions/              # Adjustable tax withholdings
│   │   ├── splash/                  # Animated launch screen
│   │   ├── tax_calculator/          # FBR slab calculation engine
│   │   ├── transactions/            # Transactions, OCR scanner & PDF reports
│   │   └── verification/            # ATL, NTN, and CPR status verification
│   └── main.dart                    # Application entry point
├── test/                            # Unit, widget, and integration test suites
├── pubspec.yaml                     # Dependencies and asset declarations
└── README.md                        # Application User Manual & Documentation
```

---

## 📄 License
This project is proprietary and confidential. Unauthorized copying, distribution, or modification is strictly prohibited.
