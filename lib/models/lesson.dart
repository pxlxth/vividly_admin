class Lesson {
  final String id;
  final String topicId;

  final String titleEs;
  final String titleEn;

  final String? subtitleEs;
  final String? subtitleEn;

  final String? witnessNameEs;
  final String? witnessNameEn;

  final String? thumbnailUrl;

  final String? introVideoUrlEs;
  final String? introVideoUrlEn;

  final String? witnessBaseVideoUrlEs;
  final String? witnessBaseVideoUrlEn;

  final String? protagonistBaseVideoUrlEs;
  final String? protagonistBaseVideoUrlEn;

  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final int? displayOrder;
  final bool? isPublished;

  Lesson({
    required this.id,
    required this.topicId,
    required this.titleEs,
    required this.titleEn,
    this.subtitleEs,
    this.subtitleEn,
    this.witnessNameEs,
    this.witnessNameEn,
    this.thumbnailUrl,
    this.introVideoUrlEs,
    this.introVideoUrlEn,
    this.witnessBaseVideoUrlEs,
    this.witnessBaseVideoUrlEn,
    this.protagonistBaseVideoUrlEs,
    this.protagonistBaseVideoUrlEn,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
    this.displayOrder,
    this.isPublished,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      topicId: json['topic_id'],

      titleEs: json['title_es'] ?? '',
      titleEn: json['title_en'] ?? '',

      subtitleEs: json['subtitle_es'],
      subtitleEn: json['subtitle_en'],

      witnessNameEs: json['witness_name_es'],
      witnessNameEn: json['witness_name_en'],

      thumbnailUrl: json['thumbnail_url'],

      introVideoUrlEs: json['intro_video_url_es'],
      introVideoUrlEn: json['intro_video_url_en'],

      witnessBaseVideoUrlEs:
          json['witness_base_video_url_es'],
      witnessBaseVideoUrlEn:
          json['witness_base_video_url_en'],

      protagonistBaseVideoUrlEs:
          json['protagonist_base_video_url_es'],
      protagonistBaseVideoUrlEn:
          json['protagonist_base_video_url_en'],

      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'])
          : null,

      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,

      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,

      displayOrder: json['display_order'],
      isPublished: json['is_published'],
    );
  }
}