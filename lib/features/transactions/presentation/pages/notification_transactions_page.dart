import 'package:fbr_tax_helper/features/transactions/domain/entities/captured_push_notification.dart';
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction.dart'
    as entity;
import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/services/notification_transaction_parser.dart';
import 'package:fbr_tax_helper/features/transactions/services/push_notification_import_service.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class NotificationTransactionsPage extends StatefulWidget {
  const NotificationTransactionsPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<NotificationTransactionsPage> createState() =>
      _NotificationTransactionsPageState();
}

class _NotificationTransactionsPageState
    extends State<NotificationTransactionsPage>
    with WidgetsBindingObserver {
  final _service = const PushNotificationImportService();

  bool _isLoading = true;
  bool _hasNotificationAccess = false;
  List<CapturedPushNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant NotificationTransactionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final hasAccess = kIsWeb
        ? false
        : await _service.isNotificationAccessEnabled();
    final notifications = kIsWeb
        ? const <CapturedPushNotification>[]
        : await _service.getCapturedNotifications();

    if (!mounted) return;
    setState(() {
      _hasNotificationAccess = hasAccess;
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _dismiss(CapturedPushNotification notification) async {
    await _service.dismissNotification(notification.id);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .where((item) => item.id != notification.id)
          .toList();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Notification dismissed.')));
  }

  Future<void> _approve(
    CapturedPushNotification notification, {
    required String category,
  }) async {
    final details = notification.details;
    final amount = details?.amount;
    if (details == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Amount was not detected, so this cannot be approved.',
            ),
          ),
        );
      return;
    }

    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Sign in before approving transactions.'),
          ),
        );
      return;
    }

    context.read<TransactionBloc>().add(
      AddTransaction(
        entity.Transaction(
          userId: userId,
          title: details.title,
          beneficiary: details.beneficiary,
          purpose: details.purpose,
          amount: amount,
          isExpense: details.isExpense,
          date: notification.postedAt,
          category: category,
        ),
      ),
    );

    await _service.dismissNotification(notification.id);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .where((item) => item.id != notification.id)
          .toList();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Transaction approved.')));
  }

  Future<void> _showDetails(CapturedPushNotification notification) async {
    final details = notification.details;
    var selectedCategory = details?.category ?? TransactionCategory.misc.name;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notification.appName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_formatDate(notification.postedAt)),
                      const SizedBox(height: 16),
                      Text(
                        'Full message',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(notification.message),
                      const SizedBox(height: 18),
                      if (details != null) _DetectedDetails(details: details),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: TransactionCategory.all
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category.name,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _dismiss(notification);
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Dismiss'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _approve(
                                  notification,
                                  category: selectedCategory,
                                );
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text('Notification import is available on Android devices.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _NotificationAccessCard(
              hasAccess: _hasNotificationAccess,
              onOpenSettings: _service.openNotificationAccessSettings,
            ),
            const SizedBox(height: 16),
            Text(
              'Fetched notifications',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_notifications.isEmpty)
              const _EmptyNotificationImports()
            else
              ..._notifications.map(
                (notification) => _NotificationImportCard(
                  notification: notification,
                  onTap: () => _showDetails(notification),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }
}

class _NotificationAccessCard extends StatelessWidget {
  const _NotificationAccessCard({
    required this.hasAccess,
    required this.onOpenSettings,
  });

  final bool hasAccess;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: hasAccess ? Colors.green.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasAccess
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: hasAccess ? Colors.green.shade700 : Colors.orange.shade800,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAccess
                        ? 'Notification access enabled'
                        : 'Enable notification access',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAccess
                        ? 'Matching payment notifications are collected even when Filer Flow is closed or offline.'
                        : 'Allow Filer Flow in Android notification access settings to import payment alerts.',
                  ),
                  if (!hasAccess) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open settings'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationImportCard extends StatelessWidget {
  const _NotificationImportCard({
    required this.notification,
    required this.onTap,
  });

  final CapturedPushNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = notification.details;
    final isExpense = details?.isExpense ?? true;
    final amount = details?.amount;
    final color = isExpense ? Colors.red.shade700 : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(isExpense ? Icons.arrow_downward : Icons.arrow_upward),
        ),
        title: Text(
          details?.title ?? notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          notification.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          amount == null ? 'No amount' : 'PKR ${amount.toStringAsFixed(0)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _DetectedDetails extends StatelessWidget {
  const _DetectedDetails({required this.details});

  final NotificationTransactionDetails details;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _DetailRow(
              label: 'Type',
              value: details.isExpense ? 'Expense' : 'Income',
            ),
            _DetailRow(
              label: 'Amount',
              value: details.amount == null
                  ? 'Not detected'
                  : 'PKR ${details.amount!.toStringAsFixed(2)}',
            ),
            _DetailRow(label: 'Title', value: details.title),
            _DetailRow(label: 'Beneficiary', value: details.beneficiary),
            _DetailRow(label: 'Purpose', value: details.purpose),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

class _EmptyNotificationImports extends StatelessWidget {
  const _EmptyNotificationImports();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No matching payment notifications yet. New alerts with sent to, paid for, or received from patterns will appear here.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
