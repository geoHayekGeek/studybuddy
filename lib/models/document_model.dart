class Document {
  final int id;
  final String title;
  final String contentType;
  final String? content;  // Add this line
  final String? summary;
  final DateTime createdAt;

  Document({
    required this.id,
    required this.title,
    required this.contentType,
    this.content,         // Add this parameter
    this.summary,
    required this.createdAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      title: json['title'],
      contentType: json['content_type'],
      content: json['content'],  // Add this line
      summary: json['summary'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content_type': contentType,
      'content': content,  // Add this line
      'summary': summary,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, String> get fileContents {
    final Map<String, String> contents = {};
    if (content == null) return contents;  // Add null check

    final sections = content!.split('\n\n--- ');

    for (String section in sections) {
      if (section.isEmpty) continue;
      final parts = section.split(' ---\n\n');
      if (parts.length == 2) {
        contents[parts[0].trim()] = parts[1].trim();
      }
    }

    return contents;
  }
}