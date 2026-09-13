class Topic {
  final String id;
  final String nameEs;
  final String nameEn;
  final int? displayOrder;
  final DateTime? createdAt;
  final String slug;

  Topic({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.displayOrder,
    required this.createdAt,
    required this.slug,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    print('TOPIC JSON: $json');

    return Topic(
      id: json['id']?.toString() ?? '',
      nameEs: json['name_es']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      displayOrder: json['display_order'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      slug: json['slug']?.toString() ?? '',
    );
  }
}