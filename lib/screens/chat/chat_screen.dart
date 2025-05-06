import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../models/document_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/chat_bubble.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_menu.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _isUploading = false;
  PlatformFile? _pickedFile;
  int? _selectedDocumentId;

  List<PlatformFile> _pickedFiles = [];

  // 1. Modified picker that uploads immediately
  Future<void> _pickFile() async {
    try {
      setState(() => _isUploading = true);
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      // Upload all files sequentially
      for (final file in result.files) {
        await _handleFileUpload(file);  // This now processes each file
      }

      // Only store successfully uploaded files
      setState(() => _pickedFiles = result.files);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

// 2. Robust upload handler
  Future<void> _handleFileUpload(PlatformFile platformFile) async {
    try {
      final authState = ref.read(authStateProvider);
      final token = authState.user?.token;
      if (token == null) throw Exception('User not authenticated');

      // Get file bytes
      final fileBytes = platformFile.bytes ?? await File(platformFile.path!).readAsBytes();
      // Create multipart request
      var uri = Uri.parse('${ApiConstants.baseUrl}/documents/text/');
      var request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['title'] = platformFile.name;

      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',  // Changed from 'content' to 'file'
        fileBytes,
        filename: platformFile.name,
      ));

      // Send request
      var response = await request.send();

      // Check response
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully!')),
        );
        await ref.read(documentsProvider.notifier).loadDocuments(authState.user!.id!);
      } else {
        var errorBody = await response.stream.bytesToString();
        throw Exception('Upload failed with status ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: ${e.toString()}')),
      );
      rethrow;
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case '.pdf': return 'pdf';
      case '.doc': case '.docx': return 'doc';
      case '.jpg': case '.jpeg': case '.png': return 'image';
      case '.txt': return 'text';
      default: return 'file';
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedDocumentId == null) { // Add null check
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await ref.read(chatMessagesProvider.notifier).askQuestionAboutDocument(
        _selectedDocumentId!, // Use selected document ID
        _messageController.text.trim(),
      );
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _generateQuiz() async {
    print("generate quiz clicked");
    if (_selectedDocumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    final authState = ref.read(authStateProvider);
    // final userId = 4;
    final userId = authState.user?.id;
    if (userId == null) return;

    try {
      final quiz = await ref.read(quizListProvider.notifier)
          .generateQuiz(_selectedDocumentId!, userId, numQuestions: 5);
      context.go('/quiz-intro/${quiz.id}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating quiz: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final documents = ref.read(documentsProvider);
      if (documents.isNotEmpty) {
        setState(() => _selectedDocumentId = documents.first.id);
      }
      // Add listener to update selection when documents change
      ref.listen<List<Document>>(documentsProvider, (_, next) {
        if (next.isNotEmpty && _selectedDocumentId == null) {
          setState(() => _selectedDocumentId = next.first.id);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentsProvider);
    final hasDocument = documents.isNotEmpty;
    final chatMessages = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Buddy'),
        actions: [
          if (documents.isNotEmpty)
            DropdownButton<int>(
              value: _selectedDocumentId,
              items: documents.map((doc) => DropdownMenuItem<int>(
                value: doc.id,
                child: Text(doc.title),
              )).toList(),
              onChanged: (value) => setState(() => _selectedDocumentId = value),
              hint: const Text('Select Document'),
            ),
          // IconButton(
          //   icon: const Icon(Icons.history),
          //   onPressed: () => context.push('/chat-history'),
          // ),
          const UserMenu(),
        ],
      ),
      body: hasDocument
          ? Column(
        children: [
          if (_pickedFiles.isNotEmpty)
            Column(
              children: _pickedFiles.map((file) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  child: ListTile(
                    leading: Icon(_getFileIcon(file.name)),
                    title: Text(file.name),
                    subtitle: Text('${(file.size / 1024).toStringAsFixed(2)} KB'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _pickedFiles.remove(file)),
                    ),
                  ),
                ),
              )).toList(),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final message = chatMessages[index];
                return ChatBubble(
                  message: message,
                  isUser: message.sender == 'user',
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                IconButton(
                  icon: _isUploading
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.attach_file),
                  color: AppColors.primary,
                  onPressed: _isUploading ? null : _pickFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask a question about the document...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: _isSending
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
                IconButton(
                  icon: const Icon(Icons.quiz, color: AppColors.primary),
                  onPressed: _generateQuiz,
                ),
              ],
            ),
          ),
        ],
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_file,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Upload a document to get started',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading ? null : _pickFile,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text('Upload Document'),
              ),
            ),
            if (_isUploading) ...[
              const SizedBox(height: 16),
              const Text('Uploading document...'),
            ],
            const SizedBox(height: 16),
            Text(
              'Supported formats: PDF, DOCX, TXT, JPG, PNG',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.pdf': return Icons.picture_as_pdf;
      case '.doc': case '.docx': return Icons.description;
      case '.jpg': case '.jpeg': case '.png': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }
}