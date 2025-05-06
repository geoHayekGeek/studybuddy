import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/document_model.dart';
import '../api/chat_api.dart';

final chatApiProvider = Provider<ChatApi>((ref) => ChatApi());

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier(ref.read(chatApiProvider));
});

final documentsProvider = StateNotifierProvider<DocumentsNotifier, List<Document>>((ref) {
  return DocumentsNotifier(ref.read(chatApiProvider));
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatApi _chatApi;

  ChatMessagesNotifier(this._chatApi) : super([]);

  Future<void> loadChatHistory(int userId) async {
    try {
      final messages = await _chatApi.getChatHistory(userId);
      state = messages;
    } catch (e) {
      // Handle error
      print('Error loading chat history: $e');
    }
  }

  Future<void> sendMessage(String message, int userId, {int? documentId}) async {
    try {
      // Add user message to state
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: message,
        sender: 'user',
        timestamp: DateTime.now(),
        documentId: documentId,
      );
      state = [...state, userMessage];

      // Send message to API and get response
      final aiResponse = await _chatApi.sendMessage(message, userId, documentId: documentId);
      state = [...state, aiResponse];
    } catch (e) {
      // Add error message
      final errorMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Error: $e',
        sender: 'system',
        timestamp: DateTime.now(),
      );
      state = [...state, errorMessage];
    }
  }

  Future<void> askQuestionAboutDocument(int documentId, String question) async {
    try {
      // Add user question to state immediately for responsive UI
      final userQuestion = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: question,
        sender: 'user',
        timestamp: DateTime.now(),
        documentId: documentId,
      );
      state = [...state, userQuestion];

      // Show loading indicator
      final loadingMessage = ChatMessage(
        id: 'loading-${DateTime.now().millisecondsSinceEpoch}',
        content: 'Thinking...',
        sender: 'system',
        timestamp: DateTime.now(),
        documentId: documentId,
      );
      state = [...state, loadingMessage];

      // Send question to API
      final answer = await _chatApi.askQuestionAboutDocument(documentId, question);

      // Remove loading indicator and add actual answer
      state = [
        ...state.where((msg) => msg.id != loadingMessage.id),
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: answer.content,
          sender: answer.sender,
          timestamp: DateTime.now(),
          documentId: documentId,
        ),
      ];
    } catch (e) {
      // Remove loading indicator if it exists
      state = state.where((msg) => !msg.id.startsWith('loading-')).toList();

      // Add error message
      state = [
        ...state,
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: 'Error: ${e.toString()}',
          sender: 'system',
          timestamp: DateTime.now(),
        ),
      ];
      rethrow;
    }
  }

  void clearChat() {
    state = [];
  }
}

class DocumentsNotifier extends StateNotifier<List<Document>> {
  final ChatApi _chatApi;
  bool _initialLoadComplete = false;

  DocumentsNotifier(this._chatApi) : super([]);

  Future<void> loadDocuments(int userId) async {
    try {
      final documents = await _chatApi.getDocuments(userId);
      state = documents;
      _initialLoadComplete = true;
    } catch (e) {
      state = [];
      _initialLoadComplete = true;
      rethrow;
    }
  }

  bool get isInitialLoadComplete => _initialLoadComplete;


  Future<Document> uploadDocuments(String title, List<PlatformFile> files, int userId) async {
    try {
      final document = await _chatApi.uploadDocuments(title, files, userId);
      state = [...state, document];
      return document;
    } catch (e) {
      print('Error uploading documents: $e');
      rethrow;
    }
  }

  Future<String> generateSummary(int documentId) async {
    try {
      final summary = await _chatApi.generateSummary(documentId);

      // Update the document in the state with the new summary
      state = state.map((document) {
        if (document.id == documentId) {
          return Document(
            id: document.id,
            title: document.title,
            contentType: document.contentType,
            summary: summary,
            createdAt: document.createdAt,
          );
        }
        return document;
      }).toList();

      return summary;
    } catch (e) {
      print('Error generating summary: $e');
      rethrow;
    }
  }
}