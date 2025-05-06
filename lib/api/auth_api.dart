import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';

class AuthApi {
  static const _tokenKey = 'token';

  Future<User> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      return _handleAuthResponse(response);
    } catch (e) {
      throw _handleError('Login', e);
    }
  }

  Future<User> register(String firstName, String lastName, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/users/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': '$firstName $lastName',
          'email': email,
          'password': password,
        }),
      );
      return _handleAuthResponse(response);
    } catch (e) {
      throw _handleError('Registration', e);
    }
  }

  Future<User> _handleAuthResponse(http.Response response) async {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      final user = User(
        token: token,
        id: data['user_id'],
        email: data['email'],
        username: data['username'],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString('user', jsonEncode({
        'id': user.id,
        'email': user.email,
        'username': user.username,
        'token': token,
      }));

      return user;
    } else if (response.statusCode == 401) {
      await _clearAuthData();
      throw Exception('Invalid credentials');
    } else {
      throw Exception('Request failed: ${response.body}');
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode != 200) {
        throw Exception('Password reset request failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error requesting password reset: $e');
    }
  }

  Future<void> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      if (response.statusCode != 200) {
        throw Exception('OTP verification failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error verifying OTP: $e');
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Password reset failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error resetting password: $e');
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    await _clearAuthData();
  }

  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('user');
  }

  Exception _handleError(String operation, dynamic error) {
    final message = error is Exception ? error.toString() : 'Unknown error';
    return Exception('$operation failed: $message');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to change password: ${response.body}');
      }
    } catch (e) {
      throw _handleError('Password change', e);
    }
  }
}

