import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studybuddy/providers/auth_provider.dart';
import 'package:studybuddy/providers/chat_provider.dart';
import 'routes.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (!next.isAuthenticated) {
        // Clear chat and documents when user logs out
        ref.read(chatMessagesProvider.notifier).clearChat();
        ref.read(documentsProvider.notifier).clearDocuments();
      }
    });

    return MaterialApp.router(
      title: 'Study Buddy',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}