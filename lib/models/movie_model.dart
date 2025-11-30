/// Movie model representing a single movie/episode
class MovieModel {
  final String uuid;
  final String title;
  final String? thumbnail;
  final String? description;

  const MovieModel({
    required this.uuid,
    required this.title,
    this.thumbnail,
    this.description,
  });

  /// Create MovieModel from JSON
  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      uuid: json['uuid'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Unknown',
      thumbnail: json['thumbnail'] ?? json['poster'] ?? json['image'],
      description: json['description'] ?? json['desc'],
    );
  }

  /// Convert MovieModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'title': title,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (description != null) 'description': description,
    };
  }
}

