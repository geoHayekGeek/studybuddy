import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz_provider.dart';
import '../../widgets/quiz_option.dart';

class QuizQuestionScreen extends ConsumerStatefulWidget {
  final String quizId;

  const QuizQuestionScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizQuestionScreen> createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends ConsumerState<QuizQuestionScreen> {
  @override
  void initState() {
    super.initState();
    // Load quiz only once when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeQuizProvider.notifier).loadQuiz(int.parse(widget.quizId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(activeQuizProvider);
    final quizNotifier = ref.read(activeQuizProvider.notifier);

    if (quizState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (quizState.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${quizState.errorMessage}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref
                    .read(activeQuizProvider.notifier)
                    .loadQuiz(int.parse(widget.quizId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final question = quizState.currentQuestion;

    if (question == null) {
      return const Scaffold(
        body: Center(child: Text('No questions available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Question'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${quizState.currentQuestionIndex + 1}/${quizState.quiz!.questions.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              question.questionText,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ...question.options.map((option) => QuizOption(
              optionText: option.optionText,
              isSelected: quizState.getSelectedOption(question.id) == option.id,
              onSelect: () => quizNotifier.selectAnswer(question.id, option.id),
            )),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Consistent padding
                  ),
                  onPressed: quizState.isFirstQuestion
                      ? null
                      : quizNotifier.previousQuestion,
                  child: const Text('Previous'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Same padding
                  ),
                  onPressed: quizState.isLastQuestion
                      ? () async {
                    try {
                      await quizNotifier.submitQuiz(4);
                      if (mounted) {
                        context.go('/quiz-result');
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error submitting quiz: $e')),
                        );
                      }
                    }
                  }
                      : quizNotifier.nextQuestion,
                  child: Text(quizState.isLastQuestion ? 'Finish' : 'Next'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}