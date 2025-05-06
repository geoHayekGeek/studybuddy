class Quiz {
  final int id;
  final String title;
  final String? description;
  final List<QuizQuestion> questions;

  Quiz({
    required this.id,
    required this.title,
    this.description,
    required this.questions,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      questions: (json['questions'] as List)
          .map((q) => QuizQuestion.fromJson(q))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class QuizQuestion {
  final int id;
  final String questionText;
  final List<QuizOptionModel> options;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'],
      questionText: json['question_text'],
      options: (json['options'] as List)
          .map((o) => QuizOptionModel.fromJson(o))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}

class QuizOptionModel {
  final int id;
  final String optionText;
  final bool? isCorrect;

  QuizOptionModel({
    required this.id,
    required this.optionText,
    this.isCorrect,
  });

  factory QuizOptionModel.fromJson(Map<String, dynamic> json) {
    return QuizOptionModel(
      id: json['id'],
      optionText: json['option_text'],
      isCorrect: json['is_correct'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'option_text': optionText,
      'is_correct': isCorrect,
    };
  }
}

class QuizAnswer {
  final int questionId;
  final int selectedOptionId;

  QuizAnswer({
    required this.questionId,
    required this.selectedOptionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'selected_option_id': selectedOptionId,
    };
  }
}

class QuizAttempt {
  final int id;
  final int quizId;
  final double score;
  final DateTime completedAt;
  final List<Map<String, dynamic>> answers;

  QuizAttempt({
    required this.id,
    required this.quizId,
    required this.score,
    required this.completedAt,
    required this.answers,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id'],
      quizId: json['quiz_id'],
      score: json['score'].toDouble(),
      completedAt: DateTime.parse(json['completed_at']),
      answers: (json['answers'] as List).cast<Map<String, dynamic>>(),
    );
  }
}
