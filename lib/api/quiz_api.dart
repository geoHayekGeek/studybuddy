import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/quiz_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizApi {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Quiz> generateQuiz(int documentId, userId, {int numQuestions = 5}) async {
    final token = await _getToken();
    try {
      final requestBody = {
        'document_id': documentId,
        'num_questions': numQuestions,
      };

      print('[DEBUG] Request body: $requestBody'); // Add this line

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/documents/generate-quiz'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return Quiz.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to generate quiz');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<List<Quiz>> getQuizzes(int userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/quizzes/?user_id=$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Quiz.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get quizzes: ${response.body}');
    }
  }

  Future<Quiz> getQuiz(int quizId) async {
    final token = await _getToken();
    print('[DEBUG] Fetching quiz $quizId');

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/quizzes/$quizId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('[DEBUG] Response status: ${response.statusCode}');
    print('[DEBUG] Response body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final jsonData = jsonDecode(response.body);
        print('[DEBUG] Parsed JSON: $jsonData');

        final quiz = Quiz.fromJson(jsonData);
        print('[DEBUG] Quiz object created with ${quiz.questions.length} questions');

        return quiz;
      } catch (e) {
        print('[ERROR] JSON parsing failed: $e');
        rethrow;
      }
    } else {
      throw Exception('Failed to get quiz: ${response.body}');
    }
  }

  Future<QuizAttempt> submitQuizAttempt(int quizId, int userId, List<QuizAnswer> answers) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/quizzes/$quizId/attempt'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'answers': answers.map((a) => {
          'question_id': a.questionId,
          'selected_option_id': a.selectedOptionId,
        }).toList(),
      }),
    );

    if (response.statusCode == 200) {
      return QuizAttempt.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to submit quiz attempt: ${response.body}');
    }

  }
}
