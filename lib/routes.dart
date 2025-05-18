import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_history_screen.dart';
import 'screens/quiz/quiz_intro_screen.dart';
import 'screens/quiz/quiz_question_screen.dart';
import 'screens/quiz/quiz_result_screen.dart';
import 'screens/auth/change_password_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) async {
      final authState = ref.read(authStateProvider);
      final documentsNotifier = ref.read(documentsProvider.notifier);
      final hasDocuments = documentsNotifier.isInitialLoadComplete
          && ref.read(documentsProvider).isNotEmpty;
      final currentPath = state.uri.path;
      final isAuthRoute = _isAuthRoute(currentPath);
      final isLoggedIn = authState.isAuthenticated;

      // Redirect unauthenticated users
      if (isLoggedIn && !documentsNotifier.isInitialLoadComplete) {
        await documentsNotifier.loadDocuments(authState.user!.id!);
      }

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Handle authenticated users
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Handle authenticated users
      if (isLoggedIn) {
        final hasLoaded = documentsNotifier.isInitialLoadComplete;

        // Redirect from auth routes to home
        if (isAuthRoute) return '/home';

        // Redirect from upload screen if documents exist
        if (_isUploadRoute(currentPath) && hasDocuments) {
          return '/chat';
        }

        // Redirect to upload if no documents
        if (hasLoaded && !hasDocuments && !_isUploadRoute(currentPath)) {
          return '/upload';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/home',
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        name: 'otpVerification',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return OTPVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/upload',
        name: 'upload',
        builder: (_, __) => const ChatScreen(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (_, __) => const ChatScreen(),
      ),
      GoRoute(
        path: '/chat-history',
        name: 'chatHistory',
        builder: (_, __) => const ChatHistoryScreen(),
      ),
      GoRoute(
        path: '/quiz-intro/:quizId',
        name: 'quizIntro',
        builder: (context, state) {
          final quizId = state.pathParameters['quizId']!;
          return QuizIntroScreen(quizId: quizId);
        },
      ),
      GoRoute(
        path: '/quiz/:quizId',
        name: 'quiz',
        builder: (context, state) {
          final quizId = state.pathParameters['quizId']!;
          return QuizQuestionScreen(quizId: quizId);
        },
      ),
      GoRoute(
        path: '/quiz-result',
        name: 'quizResult',
        builder: (_, __) => const QuizResultScreen(),
      ),
      GoRoute(
        path: '/change-password',
        name: 'changePassword',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri.path}'),
      ),
    ),
  );
});

bool _isAuthRoute(String path) => [
  '/login',
  '/signup',
  '/forgot-password',
  '/otp-verification'
].contains(path);

bool _isUploadRoute(String path) => path == '/upload';