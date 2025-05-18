// lib/screens/quiz/quiz_intro_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/constants.dart';

class QuizIntroScreen extends StatelessWidget {
  final String quizId;  // Changed from documentId to quizId

  const QuizIntroScreen({super.key, required this.quizId});  // Updated parameter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Introduction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.quiz,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to test your knowledge?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This quiz is based on the uploaded document. Answer each question and see how much you learned!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => context.go('/quiz/$quizId'),  // Changed to use quizId
              child: const Text('Start Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}