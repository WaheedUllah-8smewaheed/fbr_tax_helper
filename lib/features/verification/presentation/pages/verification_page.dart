import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/validation/fbr_validators.dart';
import '../bloc/verification_bloc.dart';
import '../bloc/verification_event.dart';
import '../bloc/verification_state.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _atlFormKey = GlobalKey<FormState>();
  final _ntnFormKey = GlobalKey<FormState>();
  final _cprFormKey = GlobalKey<FormState>();
  final _atlCnicController = TextEditingController();
  final _ntnCnicController = TextEditingController();
  final _cprController = TextEditingController();

  @override
  void dispose() {
    _atlCnicController.dispose();
    _ntnCnicController.dispose();
    _cprController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VerificationBloc(),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Live Verification'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'ATL'),
                Tab(text: 'NTN'),
                Tab(text: 'CPR'),
              ],
            ),
          ),
          body: SafeArea(
            child: BlocBuilder<VerificationBloc, VerificationState>(
              builder: (context, state) {
                return TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async =>
                          _checkAtl(context, forceRefresh: true),
                      child: _AtlStatusTab(
                        formKey: _atlFormKey,
                        controller: _atlCnicController,
                        state: state,
                        onSubmit: () => _checkAtl(context),
                      ),
                    ),
                    _NtnProfileTab(
                      formKey: _ntnFormKey,
                      controller: _ntnCnicController,
                      state: state,
                      onSubmit: () => _lookupNtn(context),
                    ),
                    _CprTrackerTab(
                      formKey: _cprFormKey,
                      controller: _cprController,
                      state: state,
                      onSubmit: () => _trackCpr(context),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkAtl(
    BuildContext context, {
    bool forceRefresh = false,
  }) async {
    if (!_atlFormKey.currentState!.validate()) return;
    context.read<VerificationBloc>().add(
      CheckAtlStatus(_atlCnicController.text, forceRefresh: forceRefresh),
    );
  }

  void _lookupNtn(BuildContext context) {
    if (!_ntnFormKey.currentState!.validate()) return;
    context.read<VerificationBloc>().add(
      LookupNtnProfile(_ntnCnicController.text),
    );
  }

  void _trackCpr(BuildContext context) {
    if (!_cprFormKey.currentState!.validate()) return;
    context.read<VerificationBloc>().add(StartTrackingCpr(_cprController.text));
  }
}

class _AtlStatusTab extends StatelessWidget {
  const _AtlStatusTab({
    required this.formKey,
    required this.controller,
    required this.state,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VerificationState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isLoading = state.atlStatus == VerificationRequestStatus.loading;

    return _VerificationScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VerificationFormPanel(
            title: 'Active Taxpayer List',
            icon: Icons.verified_user_outlined,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CnicField(controller: controller, enabled: !isLoading),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onSubmit,
                      icon: isLoading
                          ? const _ButtonSpinner()
                          : const Icon(Icons.search_outlined),
                      label: const Text('Check Status'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (state.atlStatus == VerificationRequestStatus.failure)
            _ErrorPanel(message: state.atlError ?? 'Could not check ATL.'),
          if (state.atlResult != null)
            _AtlStatusResultCard(result: state.atlResult!),
        ],
      ),
    );
  }
}

class _NtnProfileTab extends StatelessWidget {
  const _NtnProfileTab({
    required this.formKey,
    required this.controller,
    required this.state,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VerificationState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isLoading = state.ntnStatus == VerificationRequestStatus.loading;

    return _VerificationScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VerificationFormPanel(
            title: 'NTN Profile Inquiry',
            icon: Icons.business_center_outlined,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CnicField(controller: controller, enabled: !isLoading),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onSubmit,
                      icon: isLoading
                          ? const _ButtonSpinner()
                          : const Icon(Icons.manage_search_outlined),
                      label: const Text('Lookup Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading) const _SkeletonPanel(rowCount: 4),
          if (state.ntnStatus == VerificationRequestStatus.failure)
            _ErrorPanel(message: state.ntnError ?? 'Could not lookup NTN.'),
          if (state.ntnResult != null)
            _ResultPanel(
              title: state.ntnResult!.businessName.isEmpty
                  ? 'NTN Profile'
                  : state.ntnResult!.businessName,
              icon: Icons.account_balance_outlined,
              rows: [
                _InfoRow('NTN', state.ntnResult!.ntn),
                _InfoRow(
                  'Operational Status',
                  state.ntnResult!.operationalStatus,
                ),
                _InfoRow('RTO', state.ntnResult!.rto),
                if (state.ntnResult!.registrationDate != null)
                  _InfoRow(
                    'Registration Date',
                    _formatDate(state.ntnResult!.registrationDate!),
                  ),
                _InfoRow(
                  'Fetched At',
                  _formatDateTime(state.ntnResult!.fetchedAt),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CprTrackerTab extends StatelessWidget {
  const _CprTrackerTab({
    required this.formKey,
    required this.controller,
    required this.state,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VerificationState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isLoading = state.cprStatus == VerificationRequestStatus.loading;

    return _VerificationScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VerificationFormPanel(
            title: 'CPR Status Tracker',
            icon: Icons.receipt_long_outlined,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: controller,
                    enabled: !isLoading,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9-]'),
                      ),
                    ],
                    validator: CprValidator.validate,
                    decoration: const InputDecoration(
                      labelText: 'CPR number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onSubmit,
                      icon: isLoading
                          ? const _ButtonSpinner()
                          : const Icon(Icons.track_changes_outlined),
                      label: const Text('Track CPR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (state.cprStatus == VerificationRequestStatus.failure)
            _ErrorPanel(message: state.cprError ?? 'Could not track CPR.'),
          if (state.cprResult != null)
            _CprStatusPanel(result: state.cprResult!),
        ],
      ),
    );
  }
}

class _VerificationScroll extends StatelessWidget {
  const _VerificationScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child,
        ),
      ),
    );
  }
}

class _VerificationFormPanel extends StatelessWidget {
  const _VerificationFormPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0F6B57)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _CnicField extends StatelessWidget {
  const _CnicField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [CnicInputFormatter()],
      validator: CnicValidator.validate,
      decoration: const InputDecoration(
        labelText: 'CNIC',
        hintText: '00000-0000000-0',
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _AtlStatusResultCard extends StatelessWidget {
  const _AtlStatusResultCard({required this.result});

  final dynamic result;

  @override
  Widget build(BuildContext context) {
    final statusText = result.isActive
        ? 'Active Filer'
        : result.isNotFound
        ? 'Not Found'
        : 'Non-Filer';
    final statusColor = result.isActive
        ? const Color(0xFF0F6B57)
        : result.isNotFound
        ? const Color(0xFF65716C)
        : const Color(0xFFB3261E);

    return _ResultPanel(
      title: statusText,
      icon: Icons.verified_outlined,
      badgeColor: statusColor,
      rows: [
        _InfoRow('CNIC', result.cnic),
        if ((result.taxpayerName ?? '').isNotEmpty)
          _InfoRow('Taxpayer Name', result.taxpayerName!),
        _InfoRow('Source', result.source),
        _InfoRow('Verified As Of', _formatDate(result.atlPublishDate)),
        _InfoRow('Checked At', _formatDateTime(result.verifiedAt)),
      ],
    );
  }
}

class _CprStatusPanel extends StatelessWidget {
  const _CprStatusPanel({required this.result});

  final dynamic result;

  @override
  Widget build(BuildContext context) {
    return _ResultPanel(
      title: 'CPR ${result.status}',
      icon: Icons.receipt_long_outlined,
      badgeColor: result.isCleared
          ? const Color(0xFF0F6B57)
          : result.isFailed
          ? const Color(0xFFB3261E)
          : const Color(0xFFB7791F),
      rows: [
        _InfoRow('CPR Number', result.cprNumber),
        if (result.amount != null)
          _InfoRow('Amount', _formatMoney(result.amount!)),
        if ((result.bankName ?? '').isNotEmpty)
          _InfoRow('Bank', result.bankName!),
        if ((result.taxPeriod ?? '').isNotEmpty)
          _InfoRow('Tax Period', result.taxPeriod!),
        if (result.paidAt != null)
          _InfoRow('Paid At', _formatDateTime(result.paidAt!)),
        _InfoRow('Updated At', _formatDateTime(result.updatedAt)),
      ],
      footer: _CprStepper(status: result.status),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.title,
    required this.icon,
    required this.rows,
    this.badgeColor = const Color(0xFF0F6B57),
    this.footer,
  });

  final String title;
  final IconData icon;
  final Color badgeColor;
  final List<_InfoRow> rows;
  final Widget? footer;

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: badgeColor.withValues(alpha: 0.12),
                  child: Icon(icon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final row in rows)
              _SnapshotRow(label: row.label, value: row.value),
            if (footer != null) ...[const SizedBox(height: 14), footer!],
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              value.isEmpty ? '-' : value,
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

class _CprStepper extends StatelessWidget {
  const _CprStepper({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final steps = normalized == 'FAILED'
        ? const ['Submitted', 'Pending', 'Failed']
        : const ['Submitted', 'Pending', 'Cleared'];
    final activeIndex = switch (normalized) {
      'SUBMITTED' => 0,
      'CLEARED' => 2,
      'FAILED' => 2,
      _ => 1,
    };

    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
            child: _StepMarker(
              label: steps[index],
              isActive: index <= activeIndex,
              isFailed: normalized == 'FAILED' && index == 2,
            ),
          ),
          if (index != steps.length - 1)
            Container(
              width: 22,
              height: 2,
              color: index < activeIndex
                  ? const Color(0xFF0F6B57)
                  : const Color(0xFFD9DED7),
            ),
        ],
      ],
    );
  }
}

class _StepMarker extends StatelessWidget {
  const _StepMarker({
    required this.label,
    required this.isActive,
    required this.isFailed,
  });

  final String label;
  final bool isActive;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    final color = isFailed
        ? const Color(0xFFB3261E)
        : isActive
        ? const Color(0xFF0F6B57)
        : const Color(0xFF9BA6A0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDAD6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFB3261E)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel({required this.rowCount});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4DD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0; index < rowCount; index++) ...[
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECE7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (index != rowCount - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_formatDate(value)} $hour:$minute';
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
