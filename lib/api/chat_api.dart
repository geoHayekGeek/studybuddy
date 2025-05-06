import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/chat_model.dart';
import '../models/document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatApi {
  Future<ChatMessage> sendMessage(String message, int userId, {int? documentId}) async {
    final Map<String, dynamic> requestBody = {
      'message': message,
      'user_id': userId,
    };

    if (documentId != null) {
      requestBody['document_id'] = documentId;
    }

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/chat/message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  Future<List<ChatMessage>> getChatHistory(int userId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/chat/history?user_id=$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get chat history: ${response.body}');
    }
  }

  Future<Document> uploadDocuments(String title, List<PlatformFile> files, int userId) async {
    final token = await _getToken();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}/documents/text/'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;

    for (var file in files) {
      final fileBytes = file.bytes ?? await File(file.path!).readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'files',
        fileBytes,
        filename: file.name,
      ));
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return Document.fromJson(jsonDecode(responseBody));
    } else {
      throw Exception('Upload failed: $responseBody');
    }
  }

  Future<List<Document>> getDocuments(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/documents/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Document.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get documents: ${response.body}');
    }
  }

  Future<String> generateSummary(int documentId) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/documents/$documentId/summary'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['summary'] ?? 'No summary available';
    } else {
      throw Exception('Failed to generate summary: ${response.body}');
    }
  }

  Future<ChatMessage> askQuestionAboutDocument(int documentId, String question) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/documents/$documentId/question'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // ADD THIS
      },
      body: jsonEncode({
        'document_id': documentId,
        'question': question,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return ChatMessage(
        id: jsonResponse['id'].toString(),
        content: jsonResponse['answer'], // Map answer to content
        sender: 'ai',
        timestamp: DateTime.now(),
        documentId: documentId,
      );
    } else {
      throw Exception('Failed to ask question: ${response.body}');
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}