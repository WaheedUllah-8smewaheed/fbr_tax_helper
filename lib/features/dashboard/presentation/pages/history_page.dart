import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/transaction_widgets.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';

class HistoryPage extends StatelessWidget {
  final String title;
  final TransactionListMode mode;

  const HistoryPage({
    super.key,
    required this.title,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TransactionLoaded) {
            final userId = context.read<AuthService>().currentUser?.uid ?? '';
            return TransactionList(
              state: state,
              currentUserId: userId,
              transactions: state.transactions,
              mode: mode,
            );
          } else if (state is TransactionError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
