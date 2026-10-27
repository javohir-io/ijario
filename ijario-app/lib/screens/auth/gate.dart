import 'package:flutter/material.dart';

import '../../services/auth_store.dart';
import '../../widgets/empty_state.dart';
import 'auth_screen.dart';

/// Browsing is open to everyone; actions that need an account (saving,
/// chatting, booking, posting) call this first. If the person isn't signed
/// in, the sign-in screen opens and this resolves to whether they made it.
Future<bool> requireLogin(BuildContext context) async {
  if (AuthStore.instance.isLoggedIn) return true;
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => const AuthScreen(popOnSuccess: true),
    ),
  );
  return ok == true && AuthStore.instance.isLoggedIn;
}

/// Stand-in for tabs that need an account, shown to guests.
class GuestGate extends StatelessWidget {
  final String title;
  final String message;

  const GuestGate({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: EmptyState(
        title: title,
        message: message,
        actionLabel: 'Kirish',
        onAction: () => requireLogin(context),
      ),
    );
  }
}
