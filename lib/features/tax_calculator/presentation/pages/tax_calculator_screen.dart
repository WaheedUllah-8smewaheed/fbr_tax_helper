import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/datasources/tax_local_data_source.dart';
import '../../data/repositories/tax_repository_impl.dart';
import '../../domain/entities/tax_assessment.dart';
import '../../domain/entities/tax_profile.dart';
import '../../domain/usecases/calculate_tax_liability.dart';
import '../../../deductions/domain/entities/deduction_values.dart';
import '../bloc/tax_calculator_bloc.dart';
import '../bloc/tax_calculator_event.dart';
import '../bloc/tax_calculator_state.dart';
import '../../../deductions/presentation/pages/deductions_page.dart';

class TaxCalculatorScreen extends StatefulWidget {
  final TaxCalculatorBloc? bloc;
  final Widget? footer;
  final VoidCallback? onLogin;
  final String appBarTitle;
  final List<Widget> appBarActions;

  const TaxCalculatorScreen({
    super.key,
    this.bloc,
    this.footer,
    this.onLogin,
    this.appBarTitle = 'Filer Flow',
    this.appBarActions = const [],
  });

  @override
  State<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends State<TaxCalculatorScreen> {
  late final TaxCalculatorBloc _bloc;
  late final bool _ownsBloc;
  late final StreamSubscription<TaxCalculatorState> _stateSubscription;

  final TextEditingController _monthlyIncomeController =
      TextEditingController();
  final FocusNode _monthlyIncomeFocusNode = FocusNode();

  TaxProfileType _selectedType = TaxProfileType.salaried;
  String _selectedTaxYear = currentTaxYear;
  DeductionValues _deductionValues = DeductionValues.zero;
  TaxCalculatorState _state = TaxCalculatorInitial();
  String? _incomeErrorText;

  @override
  void initState() {
    super.initState();
    _ownsBloc = widget.bloc == null;
    _bloc = widget.bloc ?? _createBloc();
    _state = _bloc.state;
    _stateSubscription = _bloc.stream.listen(_handleStateChange);
  }

  static TaxCalculatorBloc _createBloc() {
    return TaxCalculatorBloc(
      calculateTaxUseCase: const CalculateTaxLiability(),
      repository: TaxRepositoryImpl(
        localDataSource: TaxLocalDataSourceImpl(
          secureStorage: const FlutterSecureStorage(),
        ),
      ),
    );
  }

  void _handleStateChange(TaxCalculatorState state) {
    if (!mounted) return;
    setState(() {
      _state = state;
      if (state is TaxCalculatorCalculated) {
        _selectedType = state.selectedType;
        _selectedTaxYear = state.taxYear;
        _deductionValues = DeductionValues(
          mobileTax: state.advanceTaxOnMobile,
          electricityTax: state.taxOnElectricityBill,
          internetTax: state.taxOnInternetBill,
          vehicleTax: state.vehicleTokenTax,
        );
        final incomeText = _formatInputAmount(state.inputSalary);
        if (_monthlyIncomeController.text != incomeText) {
          _monthlyIncomeController.text = incomeText;
        }
      } else if (state is TaxCalculatorInitial) {
        _selectedType = TaxProfileType.salaried;
        _selectedTaxYear = currentTaxYear;
        _deductionValues = DeductionValues.zero;
        _incomeErrorText = null;
        _monthlyIncomeController.clear();
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    if (_ownsBloc) {
      _bloc.close();
    }
    _monthlyIncomeController.dispose();
    _monthlyIncomeFocusNode.dispose();
    super.dispose();
  }

  void _calculateTax() {
    final income = double.tryParse(
      _monthlyIncomeController.text.replaceAll(',', '').trim(),
    );

    if (income == null || income <= 0) {
      setState(() {
        _incomeErrorText = 'Enter a monthly income above 0';
      });
      return;
    }

    setState(() {
      _incomeErrorText = null;
    });
    _monthlyIncomeFocusNode.unfocus();
    _bloc.add(
      CalculateTaxEvent(
        profileType: _selectedType,
        monthlySalary: income,
        taxYear: _selectedTaxYear,
        advanceTaxOnMobile: _deductionValues.mobileTax,
        taxOnElectricityBill: _deductionValues.electricityTax,
        taxOnInternetBill: _deductionValues.internetTax,
        vehicleTokenTax: _deductionValues.vehicleTax,
      ),
    );
  }

  Future<void> _openDeductionsPage() async {
    final values = await Navigator.of(context).push<DeductionValues>(
      MaterialPageRoute(
        builder: (context) => DeductionsPage(initialValues: _deductionValues),
      ),
    );

    if (!mounted || values == null) return;

    setState(() {
      _deductionValues = values;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Annual adjustable tax applied: ${_formatMoney(values.total)}',
          ),
        ),
      );

    if (_state is TaxCalculatorCalculated) {
      _calculateTax();
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _AdaptiveMetrics.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        centerTitle: false,
        automaticallyImplyLeading: widget.onLogin == null,
        actions: [
          ...widget.appBarActions,
          // if (widget.onLogin != null)
          //   TextButton.icon(
          //     onPressed: widget.onLogin,
          //     icon: const Icon(Icons.login, color: Colors.white),
          //     label: const Text('Login', style: TextStyle(color: Colors.white)),
          //   ),
          // IconButton(
          //   tooltip: 'Live verification',
          //   onPressed: () {
          //     Navigator.of(context).push(
          //       MaterialPageRoute(
          //         builder: (context) => const VerificationPage(),
          //       ),
          //     );
          //   },
          //   icon: const Icon(Icons.verified_user_outlined),
          // ),
          IconButton(
            tooltip: 'Clear calculator',
            onPressed: () {
              _monthlyIncomeFocusNode.unfocus();
              _bloc.add(const ResetCalculatorEvent());
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (widget.onLogin != null)
            TextButton.icon(
              onPressed: widget.onLogin,
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openDeductionsPage,
        child: const Icon(Icons.receipt_long_outlined),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            metrics.horizontalPadding,
            metrics.verticalPadding,
            metrics.horizontalPadding,
            metrics.verticalPadding + keyboardInset,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderBand(
                    state: _state,
                    metrics: metrics,
                    taxYear: _selectedTaxYear,
                  ),
                  SizedBox(height: metrics.sectionSpacing),
                  _CalculatorForm(
                    metrics: metrics,
                    controller: _monthlyIncomeController,
                    focusNode: _monthlyIncomeFocusNode,
                    selectedType: _selectedType,
                    selectedTaxYear: _selectedTaxYear,
                    deductionValues: _deductionValues,
                    incomeErrorText: _incomeErrorText,
                    isLoading: _state is TaxCalculatorLoading,
                    onTypeChanged: (type) {
                      setState(() {
                        _selectedType = type;
                      });
                    },
                    onCalculate: _calculateTax,
                    onTaxYearChanged: (taxYear) {
                      setState(() {
                        _selectedTaxYear = taxYear;
                      });
                    },
                  ),
                  SizedBox(height: metrics.sectionSpacing),
                  _buildStateContent(_state),
                  if (widget.footer != null) ...[
                    const SizedBox(height: 20),
                    widget.footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent(TaxCalculatorState state) {
    if (state is TaxCalculatorLoading) {
      return const _LoadingPanel();
    }

    if (state is TaxCalculatorError) {
      return _MessagePanel(
        icon: Icons.error_outline_rounded,
        title: 'Could not complete calculation',
        message: state.errorMessage,
      );
    }

    if (state is TaxCalculatorCalculated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResultsGrid(assessment: state.assessment),
          const SizedBox(height: 20),
          _FilingReceipt(
            profileType: state.selectedType,
            monthlyIncome: state.inputSalary,
            taxYear: state.taxYear,
            deductionValues: DeductionValues(
              mobileTax: state.advanceTaxOnMobile,
              electricityTax: state.taxOnElectricityBill,
              internetTax: state.taxOnInternetBill,
              vehicleTax: state.vehicleTokenTax,
            ),
            assessment: state.assessment,
          ),
        ],
      );
    }

    return const _MessagePanel(
      icon: Icons.calculate_outlined,
      title: 'Start with monthly gross income',
      message: 'Choose your profile type and calculate your estimated tax.',
    );
  }
}

class _AdaptiveMetrics {
  final double width;
  final double height;
  final Orientation orientation;

  const _AdaptiveMetrics({
    required this.width,
    required this.height,
    required this.orientation,
  });

  factory _AdaptiveMetrics.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return _AdaptiveMetrics(
      width: size.width,
      height: size.height,
      orientation: MediaQuery.orientationOf(context),
    );
  }

  bool get isCompact => width < 600;
  bool get isNarrow => width < 420;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isLandscapePhone =>
      isCompact && orientation == Orientation.landscape;
  bool get stackHeader => width < 680;
  bool get useWideForm => width >= 700 || isLandscapePhone;
  bool get compactSnapshotRows => width < 460;

  double get horizontalPadding {
    if (width < 360) return 12;
    if (isCompact) return 16;
    if (isTablet) return 28;
    return 40;
  }

  double get verticalPadding => isCompact ? 14 : 24;
  double get sectionSpacing => isCompact ? 14 : 20;
  double get panelPadding => isCompact ? 16 : 20;
  double get maxContentWidth => width >= 1180 ? 1080 : 980;

  int get resultColumns {
    if (width >= 900) return 4;
    if (width >= 560) return 2;
    return 1;
  }

  double get resultAspectRatio {
    if (resultColumns == 1) return isNarrow ? 3.0 : 3.4;
    if (resultColumns == 2) return width < 700 ? 1.35 : 1.55;
    return 1.5;
  }
}

class _HeaderBand extends StatelessWidget {
  final TaxCalculatorState state;
  final _AdaptiveMetrics metrics;
  final String taxYear;

  const _HeaderBand({
    required this.state,
    required this.metrics,
    required this.taxYear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = state is TaxCalculatorCalculated
        ? 'Estimate ready'
        : state is TaxCalculatorLoading
        ? 'Calculating'
        : 'Tax Year $taxYear';

    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0F6B57),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.account_balance_outlined, color: Colors.white),
    );
    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pakistan income tax estimator',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Salary, freelance export income, monthly deductions, and filing-ready totals.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF4D5A55),
          ),
        ),
      ],
    );
    final statusChip = Chip(
      avatar: const Icon(Icons.verified_outlined, size: 18),
      label: Text(statusText),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFC8D8CD)),
    );

    return Container(
      padding: EdgeInsets.all(metrics.panelPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8D8CD)),
      ),
      child: metrics.stackHeader
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: headerText),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: statusChip),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(child: headerText),
                const SizedBox(width: 12),
                statusChip,
              ],
            ),
    );
  }
}

class _CalculatorForm extends StatelessWidget {
  final _AdaptiveMetrics metrics;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TaxProfileType selectedType;
  final String selectedTaxYear;
  final DeductionValues deductionValues;
  final String? incomeErrorText;
  final bool isLoading;
  final ValueChanged<TaxProfileType> onTypeChanged;
  final ValueChanged<String> onTaxYearChanged;
  final VoidCallback onCalculate;

  const _CalculatorForm({
    required this.metrics,
    required this.controller,
    required this.focusNode,
    required this.selectedType,
    required this.selectedTaxYear,
    required this.deductionValues,
    required this.incomeErrorText,
    required this.isLoading,
    required this.onTypeChanged,
    required this.onTaxYearChanged,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E4DD)),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculator',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _ProfileTypeSelector(
              metrics: metrics,
              selectedType: selectedType,
              isLoading: isLoading,
              onTypeChanged: onTypeChanged,
            ),
            const SizedBox(height: 16),
            _DeductionSummary(values: deductionValues),
            const SizedBox(height: 16),
            _IncomeInputRow(
              metrics: metrics,
              controller: controller,
              focusNode: focusNode,
              selectedTaxYear: selectedTaxYear,
              isLoading: isLoading,
              incomeErrorText: incomeErrorText,
              onTaxYearChanged: onTaxYearChanged,
              onCalculate: onCalculate,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeductionSummary extends StatelessWidget {
  const _DeductionSummary({required this.values});

  final DeductionValues values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = values.hasAnyValue
        ? 'Adjustable tax paid: ${_formatMoney(values.total)}'
        : 'Adjustable tax paid: PKR 0';

    return Row(
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 18,
          color: Color(0xFF65716C),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF65716C),
              fontWeight: values.hasAnyValue ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileTypeSelector extends StatelessWidget {
  final _AdaptiveMetrics metrics;
  final TaxProfileType selectedType;
  final bool isLoading;
  final ValueChanged<TaxProfileType> onTypeChanged;

  const _ProfileTypeSelector({
    required this.metrics,
    required this.selectedType,
    required this.isLoading,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isTight = availableWidth < 360;
        final showIcons = availableWidth >= 390;
        final labelStyle = theme.textTheme.labelLarge?.copyWith(
          fontSize: isTight ? 12 : null,
          fontWeight: FontWeight.w600,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<TaxProfileType>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              style: ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(
                    horizontal: isTight ? 4 : 8,
                    vertical: metrics.isNarrow ? 10 : 12,
                  ),
                ),
                textStyle: WidgetStatePropertyAll(labelStyle),
                visualDensity: isTight
                    ? VisualDensity.compact
                    : VisualDensity.standard,
              ),
              segments: [
                ButtonSegment(
                  value: TaxProfileType.salaried,
                  icon: showIcons ? const Icon(Icons.badge_outlined) : null,
                  label: const _SegmentLabel('Salaried'),
                ),
                ButtonSegment(
                  value: TaxProfileType.registeredFreelancer,
                  icon: showIcons
                      ? const Icon(Icons.workspace_premium_outlined)
                      : null,
                  label: const _SegmentLabel('Registered'),
                ),
                ButtonSegment(
                  value: TaxProfileType.unregisteredExporter,
                  icon: showIcons ? const Icon(Icons.public_outlined) : null,
                  label: const _SegmentLabel('Other'),
                ),
              ],
              selected: {selectedType},
              onSelectionChanged: isLoading
                  ? null
                  : (selection) => onTypeChanged(selection.first),
            ),
            const SizedBox(height: 8),
            _ProfileNotes(selectedType: selectedType),
          ],
        );
      },
    );
  }
}

class _ProfileNotes extends StatelessWidget {
  const _ProfileNotes({required this.selectedType});

  final TaxProfileType selectedType;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        _ProfileNote(
          label: 'Salaried',
          note: 'progressive slabs',
          isSelected: selectedType == TaxProfileType.salaried,
        ),
        _ProfileNote(
          label: 'Registered',
          note: 'PSEB export 0.25%',
          isSelected: selectedType == TaxProfileType.registeredFreelancer,
        ),
        _ProfileNote(
          label: 'Other',
          note: 'export WHT 1%',
          isSelected: selectedType == TaxProfileType.unregisteredExporter,
        ),
      ],
    );
  }
}

class _ProfileNote extends StatelessWidget {
  const _ProfileNote({
    required this.label,
    required this.note,
    required this.isSelected,
  });

  final String label;
  final String note;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF65716C);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: note),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(color: color),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  final String text;

  const _SegmentLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
      ),
    );
  }
}

class _IncomeInputRow extends StatelessWidget {
  final _AdaptiveMetrics metrics;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String selectedTaxYear;
  final bool isLoading;
  final String? incomeErrorText;
  final ValueChanged<String> onTaxYearChanged;
  final VoidCallback onCalculate;

  const _IncomeInputRow({
    required this.metrics,
    required this.controller,
    required this.focusNode,
    required this.selectedTaxYear,
    required this.isLoading,
    required this.incomeErrorText,
    required this.onTaxYearChanged,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    final input = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !isLoading,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: 'Monthly gross income',
        prefixText: 'PKR ',
        errorText: incomeErrorText,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => onCalculate(),
    );
    final taxYearDropdown = DropdownButtonFormField<String>(
      key: ValueKey(selectedTaxYear),
      initialValue: selectedTaxYear,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tax year',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final taxYear in supportedTaxYears)
          DropdownMenuItem<String>(value: taxYear, child: Text(taxYear)),
      ],
      onChanged: isLoading
          ? null
          : (value) {
              if (value != null) onTaxYearChanged(value);
            },
    );
    final button = FilledButton.icon(
      onPressed: isLoading ? null : onCalculate,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.calculate_outlined),
      label: const Text('Calculate'),
    );

    if (!metrics.useWideForm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          taxYearDropdown,
          const SizedBox(height: 12),
          input,
          const SizedBox(height: 12),
          SizedBox(height: 48, child: button),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: metrics.isLandscapePhone ? 180 : 210,
          child: taxYearDropdown,
        ),
        const SizedBox(width: 12),
        Expanded(child: input),
        const SizedBox(width: 12),
        SizedBox(
          width: metrics.isLandscapePhone ? 140 : 160,
          height: 56,
          child: button,
        ),
      ],
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final TaxAssessment assessment;

  const _ResultsGrid({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final metrics = _AdaptiveMetrics.of(context);

    return GridView.count(
      crossAxisCount: metrics.resultColumns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: metrics.resultAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _MetricTile(
          icon: Icons.payments_outlined,
          label: 'Annual income',
          value: _formatMoney(assessment.annualGrossIncome),
        ),
        _MetricTile(
          icon: Icons.receipt_long_outlined,
          label: 'Net annual tax',
          value: _formatMoney(assessment.annualTaxLiability),
        ),
        _MetricTile(
          icon: Icons.fact_check_outlined,
          label: 'Adjustable tax paid',
          value: _formatMoney(assessment.annualAdjustableTaxPaid),
        ),
        _MetricTile(
          icon: Icons.calendar_month_outlined,
          label: 'Monthly tax payable',
          value: _formatMoney(assessment.monthlyTaxLiability),
        ),
        _MetricTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Take-home pay',
          value: _formatMoney(assessment.monthlyTakeHomePay),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _AdaptiveMetrics.of(context);
    final valueText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final labelText = Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: const Color(0xFF65716C),
      ),
    );

    if (metrics.resultColumns == 1) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E4DD)),
        ),
        child: Padding(
          padding: EdgeInsets.all(metrics.isNarrow ? 14 : 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0F6B57)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 4), valueText],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4DD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: const Color(0xFF0F6B57)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 4), valueText],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilingReceipt extends StatelessWidget {
  final TaxProfileType profileType;
  final double monthlyIncome;
  final String taxYear;
  final DeductionValues deductionValues;
  final TaxAssessment assessment;

  const _FilingReceipt({
    required this.profileType,
    required this.monthlyIncome,
    required this.taxYear,
    required this.deductionValues,
    required this.assessment,
  });

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    pw.Widget buildPdfRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
            pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Filing Receipt',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Effective rate: ${assessment.effectiveTaxRate.toStringAsFixed(2)}%',
              ),
              pw.SizedBox(height: 24),
              buildPdfRow('Tax year', taxYear),
              buildPdfRow('Profile', _profileTypeLabel(profileType)),
              pw.Divider(height: 24),
              buildPdfRow(
                'Annual Gross Income',
                _formatMoney(assessment.annualGrossIncome),
              ),
              buildPdfRow(
                'Annual Tax Before Adjustments',
                _formatMoney(assessment.annualTaxBeforeAdjustments),
              ),
              if (deductionValues.hasAnyValue) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Deductions Applied',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (deductionValues.mobileTax > 0)
                  buildPdfRow(
                    'Mobile Tax Paid',
                    _formatMoney(deductionValues.mobileTax),
                  ),
                if (deductionValues.electricityTax > 0)
                  buildPdfRow(
                    'Electricity Tax Paid',
                    _formatMoney(deductionValues.electricityTax),
                  ),
                if (deductionValues.internetTax > 0)
                  buildPdfRow(
                    'Internet Tax Paid',
                    _formatMoney(deductionValues.internetTax),
                  ),
                if (deductionValues.vehicleTax > 0)
                  buildPdfRow(
                    'Vehicle Tax Paid',
                    _formatMoney(deductionValues.vehicleTax),
                  ),
                buildPdfRow(
                  'Total Adjustable Tax Paid',
                  _formatMoney(assessment.annualAdjustableTaxPaid),
                ),
                pw.SizedBox(height: 8),
              ],
              buildPdfRow(
                'Net Annual Tax Payable',
                _formatMoney(assessment.annualTaxLiability),
              ),
              buildPdfRow(
                'Annual Take-Home',
                _formatMoney(
                  assessment.annualGrossIncome - assessment.annualTaxLiability,
                ),
              ),
              pw.Divider(height: 24),
              buildPdfRow('Monthly Gross Income', _formatMoney(monthlyIncome)),
              buildPdfRow(
                'Monthly Tax Payable',
                _formatMoney(assessment.monthlyTaxLiability),
              ),
              buildPdfRow(
                'Monthly In-Hand',
                _formatMoney(assessment.monthlyTakeHomePay),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _AdaptiveMetrics.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D18B)),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined, color: Color(0xFF8A6100)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filing Receipt',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Effective rate: ${assessment.effectiveTaxRate.toStringAsFixed(2)}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SnapshotRow(label: 'Tax year', value: taxYear),
            _SnapshotRow(
              label: 'Profile',
              value: _profileTypeLabel(profileType),
            ),
            const Divider(height: 20),
            _SnapshotRow(
              label: 'Annual Gross Income',
              value: _formatMoney(assessment.annualGrossIncome),
            ),
            _SnapshotRow(
              label: 'Annual Tax Before Adjustments',
              value: _formatMoney(assessment.annualTaxBeforeAdjustments),
            ),
            if (deductionValues.hasAnyValue) ...[
              const SizedBox(height: 6),
              Text(
                'Deductions Applied',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF8A6100),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (deductionValues.mobileTax > 0)
                _SnapshotRow(
                  label: 'Mobile Tax Paid',
                  value: _formatMoney(deductionValues.mobileTax),
                ),
              if (deductionValues.electricityTax > 0)
                _SnapshotRow(
                  label: 'Electricity Tax Paid',
                  value: _formatMoney(deductionValues.electricityTax),
                ),
              if (deductionValues.internetTax > 0)
                _SnapshotRow(
                  label: 'Internet Tax Paid',
                  value: _formatMoney(deductionValues.internetTax),
                ),
              if (deductionValues.vehicleTax > 0)
                _SnapshotRow(
                  label: 'Vehicle Tax Paid',
                  value: _formatMoney(deductionValues.vehicleTax),
                ),
              _SnapshotRow(
                label: 'Total Adjustable Tax Paid',
                value: _formatMoney(assessment.annualAdjustableTaxPaid),
              ),
            ],
            _SnapshotRow(
              label: 'Net Annual Tax Payable',
              value: _formatMoney(assessment.annualTaxLiability),
            ),
            _SnapshotRow(
              label: 'Annual Take-Home',
              value: _formatMoney(
                assessment.annualGrossIncome - assessment.annualTaxLiability,
              ),
            ),
            const Divider(height: 20),
            _SnapshotRow(
              label: 'Monthly Gross Income',
              value: _formatMoney(monthlyIncome),
            ),
            _SnapshotRow(
              label: 'Monthly Tax Payable',
              value: _formatMoney(assessment.monthlyTaxLiability),
            ),
            _SnapshotRow(
              label: 'Monthly In-Hand',
              value: _formatMoney(assessment.monthlyTakeHomePay),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Printing.layoutPdf(
                    onLayout: (format) => _generatePdf(),
                  );
                },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print Receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final String label;
  final String value;

  const _SnapshotRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _AdaptiveMetrics.of(context);

    if (metrics.compactSnapshotRows) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF65716C),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF65716C),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE0E4DD))),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _AdaptiveMetrics.of(context);
    final iconWidget = Icon(icon, color: const Color(0xFF0F6B57), size: 32);
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF65716C),
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4DD)),
      ),
      child: Padding(
        padding: EdgeInsets.all(metrics.panelPadding),
        child: metrics.isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [iconWidget, const SizedBox(height: 12), textContent],
              )
            : Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 14),
                  Expanded(child: textContent),
                ],
              ),
      ),
    );
  }
}

String _profileTypeLabel(TaxProfileType type) {
  return switch (type) {
    TaxProfileType.salaried => 'Salaried individual',
    TaxProfileType.registeredFreelancer => 'Registered freelancer',
    TaxProfileType.unregisteredExporter => 'Unregistered exporter',
  };
}

String _formatMoney(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }

  final sign = value < 0 ? '-' : '';
  return 'PKR $sign${buffer.toString()}';
}

String _formatInputAmount(double value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
