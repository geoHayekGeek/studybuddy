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
  bool _isGeneratingQuiz = false;
  int? _selectedDocumentId;

  List<PlatformFile> _pickedFiles = [];

  // Helper getter to check if any operation is in progress
  bool get _isLoading => _isSending || _isUploading || _isGeneratingQuiz;

  Future<void> _pickFile() async {
    if (_isLoading) return; // Prevent action if anything is loading

    try {
      setState(() => _isUploading = true);
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        await _handleFileUpload(file);
      }

      setState(() => _pickedFiles = result.files);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _handleFileUpload(PlatformFile platformFile) async {
    try {
      final authState = ref.read(authStateProvider);
      final token = authState.user?.token;
      if (token == null) throw Exception('User not authenticated');

      final fileBytes = platformFile.bytes ?? await File(platformFile.path!).readAsBytes();
      var uri = Uri.parse('${ApiConstants.baseUrl}/documents/text/');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = platformFile.name;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: platformFile.name,
      ));
      var response = await request.send();

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
    if (_isLoading) return; // Prevent action if anything is loading

    if (_selectedDocumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) return;
    setState(() => _isSending = true);

    try {
      await ref.read(chatMessagesProvider.notifier).askQuestionAboutDocument(
        _selectedDocumentId!,
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
    if (_isLoading) return;

    if (_selectedDocumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    setState(() => _isGeneratingQuiz = true);

    try {
      final quiz = await ref.read(quizListProvider.notifier)
          .generateQuiz(_selectedDocumentId!, 4, numQuestions: 5); // Use selected ID
      context.go('/quiz-intro/${quiz.id}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating quiz: $e')),
      );
    } finally {
      setState(() => _isGeneratingQuiz = false);
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

    // Create a loading message based on current operation
    String? loadingMessage;
    if (_isUploading) loadingMessage = 'Uploading document...';
    else if (_isSending) loadingMessage = 'Sending message...';
    else if (_isGeneratingQuiz) loadingMessage = 'Generating quiz...';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3461FD),
        elevation: 4,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12.0),
          child: Icon(
            Icons.psychology,
            color: Colors.white,
            size: 30,
          ),
        ),
        centerTitle: true,
        title: documents.isNotEmpty
            ? SizedBox(
          width: MediaQuery.of(context).size.width * 0.6, // Limit width to 60% of screen width
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedDocumentId,
              isExpanded: true, // Use maximum width
              items: documents.map((doc) {
                return DropdownMenuItem<int>(
                  value: doc.id,
                  child: Text(
                    doc.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: _isLoading ? null : (value) => setState(() => _selectedDocumentId = value),
              dropdownColor: const Color(0xFF3461FD),
              iconEnabledColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            ),
          ),
        )
            : const SizedBox(),
        actions: const [UserMenu()],
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
                      // Disable file removal when loading
                      onPressed: _isLoading ? null : () => setState(() => _pickedFiles.remove(file)),
                    ),
                  ),
                ),
              )).toList(),
            ),
          // Display loading indicator if any operation is in progress
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(loadingMessage ?? 'Processing...'),
                ],
              ),
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
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file),
                  color: _isLoading && !_isUploading ? Colors.grey : AppColors.primary,
                  onPressed: _isLoading ? null : _pickFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isLoading, // Disable text field when loading
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
                    onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  color: _isLoading && !_isSending ? Colors.grey : AppColors.primary,
                  onPressed: _isLoading ? null : _sendMessage,
                ),
                IconButton(
                  icon: _isGeneratingQuiz
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.quiz),
                  color: _isLoading && !_isGeneratingQuiz ? Colors.grey : AppColors.primary,
                  onPressed: _isLoading ? null : _generateQuiz,
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
              onPressed: _isLoading ? null : _pickFile,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isUploading
                  ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)
              )
                  : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text('Upload Document'),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              Text(loadingMessage ?? 'Processing...'),
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