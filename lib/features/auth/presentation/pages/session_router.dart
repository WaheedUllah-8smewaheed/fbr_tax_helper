import 'package:fbr_tax_helper/features/auth/presentation/pages/dashboard_screen.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/login_page.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SessionRouter extends StatelessWidget {
  const SessionRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listens to native Firebase authentication session changes
      stream: context.read<AuthService>().authStateChanges(),
      builder: (context, snapshot) {
        // While Firebase is reading the local device token key on startup
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If a valid user session token is found on the device hardware
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen(); // Full tracking + calculator view
        }

        // Signed-out users authenticate before opening account features.
        return const LoginPage();
      },
    );
  }
}
