// lib/providers/quiz_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz_model.dart';
import '../api/quiz_api.dart';

final quizApiProvider = Provider<QuizApi>((ref) => QuizApi());

final quizListProvider = StateNotifierProvider<QuizzesNotifier, QuizListState>((ref) {
  return QuizzesNotifier(ref.read(quizApiProvider));
});

final activeQuizProvider = StateNotifierProvider.autoDispose<ActiveQuizNotifier, ActiveQuizState>(
      (ref) => ActiveQuizNotifier(ref.read(quizApiProvider)),
);

class QuizListState {
  final bool isLoading;
  final List<Quiz> quizzes;
  final String? errorMessage;

  QuizListState({
    required this.isLoading,
    required this.quizzes,
    this.errorMessage,
  });

  factory QuizListState.initial() {
    return QuizListState(isLoading: false, quizzes: []);
  }

  factory QuizListState.loading() {
    return QuizListState(isLoading: true, quizzes: []);
  }

  factory QuizListState.loaded(List<Quiz> quizzes) {
    return QuizListState(isLoading: false, quizzes: quizzes);
  }

  factory QuizListState.error(String message) {
    return QuizListState(isLoading: false, quizzes: [], errorMessage: message);
  }
}

class QuizzesNotifier extends StateNotifier<QuizListState> {
  final QuizApi _quizApi;

  QuizzesNotifier(this._quizApi) : super(QuizListState.initial());

  Future<void> loadQuizzes(int userId) async {
    state = QuizListState.loading();
    try {
      final quizzes = await _quizApi.getQuizzes(userId);
      state = QuizListState.loaded(quizzes);
    } catch (e) {
      state = QuizListState.error(e.toString());
    }
  }

  Future<Quiz> generateQuiz(int documentId, int userId, {int numQuestions = 5}) async {
    state = QuizListState.loading();
    try {
      final quiz = await _quizApi.generateQuiz(documentId, userId, numQuestions: numQuestions);
      state = QuizListState.loaded([...state.quizzes, quiz]);
      return quiz;
    } catch (e) {
      state = QuizListState.error(e.toString());
      rethrow;
    }
  }
}

class ActiveQuizState {
  final bool isLoading;
  final Quiz? quiz;
  final int currentQuestionIndex;
  final Map<int, int> userAnswers; // questionId -> selectedOptionId
  final QuizAttempt? quizResult;
  final String? errorMessage;

  ActiveQuizState({
    required this.isLoading,
    this.quiz,
    required this.currentQuestionIndex,
    required this.userAnswers,
    this.quizResult,
    this.errorMessage,
  });

  factory ActiveQuizState.initial() {
    return ActiveQuizState(
      isLoading: false,
      currentQuestionIndex: 0,
      userAnswers: {},
    );
  }

  factory ActiveQuizState.loading() {
    return ActiveQuizState(
      isLoading: true,
      currentQuestionIndex: 0,
      userAnswers: {},
    );
  }

  factory ActiveQuizState.loaded(Quiz quiz) {
    return ActiveQuizState(
      isLoading: false,
      quiz: quiz,
      currentQuestionIndex: 0,
      userAnswers: {},
    );
  }

  factory ActiveQuizState.error(String message) {
    return ActiveQuizState(
      isLoading: false,
      currentQuestionIndex: 0,
      userAnswers: {},
      errorMessage: message,
    );
  }

  bool get isLastQuestion {
    if (quiz == null) return true;
    return currentQuestionIndex >= quiz!.questions.length - 1;
  }

  bool get isFirstQuestion {
    return currentQuestionIndex <= 0;
  }

  QuizQuestion? get currentQuestion {
    print(quiz);
    if (quiz == null || quiz!.questions.isEmpty) {
      return null;
    }
    if (currentQuestionIndex >= quiz!.questions.length) {
      return null;
    }
    print("test2");
    print(quiz!.questions[currentQuestionIndex]);
    return quiz!.questions[currentQuestionIndex];
  }

  int? getSelectedOption(int questionId) {
    return userAnswers[questionId];
  }

  ActiveQuizState copyWith({
    bool? isLoading,
    Quiz? quiz,
    int? currentQuestionIndex,
    Map<int, int>? userAnswers,
    QuizAttempt? quizResult,
    String? errorMessage,
  }) {
    return ActiveQuizState(
      isLoading: isLoading ?? this.isLoading,
      quiz: quiz ?? this.quiz,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      userAnswers: userAnswers ?? this.userAnswers,
      quizResult: quizResult ?? this.quizResult,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ActiveQuizNotifier extends StateNotifier<ActiveQuizState> {
  final QuizApi _quizApi;

  ActiveQuizNotifier(this._quizApi) : super(ActiveQuizState.initial());

  Future<void> loadQuiz(int quizId) async {
    print('[STATE] Starting to load quiz $quizId');
    state = ActiveQuizState.loading();

    try {
      print('[STATE] Calling API for quiz $quizId');
      final quiz = await _quizApi.getQuiz(quizId);

      print('[STATE] Received quiz with ${quiz.questions.length} questions');
      for (var q in quiz.questions) {
        print(' - Question ${q.id}: ${q.questionText} (${q.options.length} options)');
      }

      state = ActiveQuizState.loaded(quiz);
      print('[STATE] Quiz loaded successfully');
    } catch (e) {
      print('[STATE ERROR] Failed to load quiz: $e');
      state = ActiveQuizState.error(e.toString());
    }
  }

  void nextQuestion() {
    if (state.isLastQuestion) return;
    state = state.copyWith(
      currentQuestionIndex: state.currentQuestionIndex + 1,
    );
  }

  void previousQuestion() {
    if (state.isFirstQuestion) return;
    state = state.copyWith(
      currentQuestionIndex: state.currentQuestionIndex - 1,
    );
  }

  void selectAnswer(int questionId, int optionId) {
    final updatedAnswers = Map<int, int>.from(state.userAnswers);
    updatedAnswers[questionId] = optionId;
    state = state.copyWith(userAnswers: updatedAnswers);
  }

  Future<QuizAttempt> submitQuiz(int userId) async {
    state = state.copyWith(isLoading: true);
    try {
      if (state.quiz == null) {
        throw Exception('No active quiz to submit');
      }

      final answers = state.userAnswers.entries.map((entry) {
        return QuizAnswer(
          questionId: entry.key,
          selectedOptionId: entry.value,
        );
      }).toList();

      final result = await _quizApi.submitQuizAttempt(
        state.quiz!.id,
        userId,
        answers,
      );

      state = state.copyWith(
        isLoading: false,
        quizResult: result,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  void resetQuiz() {
    state = ActiveQuizState.initial();
  }
}