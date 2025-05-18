import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../api/auth_api.dart';
import 'chat_provider.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authApiProvider), ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApi _authApi;
  final Ref _ref;

  AuthNotifier(this._authApi, this._ref) : super(AuthState.initial()) {
    loadUser();
  }

  Future<void> loadUser() async {
    state = AuthState.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      final token = await _authApi.getToken();

      if (userJson != null && token != null) {
        final user = User.fromJson(jsonDecode(userJson));
        state = AuthState.authenticated(user);
        // Load documents after authentication - FIXED REFERENCE
        await _ref.read(documentsProvider.notifier).loadDocuments(user.id!);
      } else {
        await _authApi.logout();
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final user = await _authApi.login(email, password);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> register(String firstName, String lastName, String email, String password) async {
    state = AuthState.loading();
    try {
      final user = await _authApi.register(firstName, lastName, email, password);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    try {
      await _authApi.logout();
      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    state = AuthState.loading();
    try {
      await _authApi.requestPasswordReset(email);
      state = AuthState.unauthenticated(message: 'Reset email sent');
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> verifyOTP(String email, String otp) async {
    state = AuthState.loading();
    try {
      await _authApi.verifyOTP(email, otp);
      state = AuthState.unauthenticated(message: 'OTP verified');
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    state = AuthState.loading();
    try {
      await _authApi.resetPassword(email, otp, newPassword);
      state = AuthState.unauthenticated(message: 'Password reset');
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Store existing user before clearing state
    final existingUser = state.user;
    state = AuthState.loading();

    try {
      await _authApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (existingUser == null) {
        throw Exception('No authenticated user in state.');
      }

      // Reload documents after password change
      await _ref.read(documentsProvider.notifier).loadDocuments(existingUser.id!);

      // Update state with refreshed user data
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      final updatedUser = userJson != null
          ? User.fromJson(jsonDecode(userJson))
          : existingUser;

      state = AuthState.authenticated(updatedUser);
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final String? errorMessage;
  final String? message;

  AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.user,
    this.errorMessage,
    this.message,
  });

  factory AuthState.initial() => AuthState(
    isLoading: true,
    isAuthenticated: false,
  );

  factory AuthState.loading() => AuthState(
    isLoading: true,
    isAuthenticated: false,
  );

  factory AuthState.authenticated(User user) => AuthState(
    isLoading: false,
    isAuthenticated: true,
    user: user,
  );

  factory AuthState.unauthenticated({String? message}) => AuthState(
    isLoading: false,
    isAuthenticated: false,
    message: message,
  );

  factory AuthState.error(String message) => AuthState(
    isLoading: false,
    isAuthenticated: false,
    errorMessage: message,
  );
}

