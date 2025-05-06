// lib/widgets/user_menu.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class UserMenu extends ConsumerWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton(
      icon: const Icon(Icons.person),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 10),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'changePassword',
          child: ListTile(
            leading: Icon(Icons.lock),
            title: Text('Change Password'),
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'logout') {
          await ref.read(authStateProvider.notifier).logout();
          if (context.mounted) {
            context.go('/login');
          }
        } else if (value == 'changePassword') {
          if (context.mounted) {
            context.push('/change-password');
          }
        }
      },
    );
  }
}