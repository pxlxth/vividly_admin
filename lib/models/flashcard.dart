class Flashcard {
  final String id;
  final String lessonId;
  final String titleEs;
  final String contentEs;
  final String? imageUrl;
  final int? displayOrder;
  final DateTime? createdAt;
  final String? titleEn;
  final String? contentEn;

  Flashcard({
    required this.id,
    required this.lessonId,
    required this.titleEs,
    required this.contentEs,
    this.imageUrl,
    this.displayOrder,
    this.createdAt,
    this.titleEn,
    this.contentEn,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'],
      lessonId: json['lesson_id'],
      titleEs: json['title_es'] ?? '',
      contentEs: json['content_es'] ?? '',
      imageUrl: json['image_url'],
      displayOrder: json['display_order'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      titleEn: json['title_en'],
      contentEn: json['content_en'],
    );
  }
}