/// Movie series model representing a collection of movies
class MovieSeriesModel {
  final String uuid;
  final String title;
  final String? thumbnail;
  final String? description;

  const MovieSeriesModel({
    required this.uuid,
    required this.title,
    this.thumbnail,
    this.description,
  });

  /// Create MovieSeriesModel from JSON
  factory MovieSeriesModel.fromJson(Map<String, dynamic> json) {
    return MovieSeriesModel(
      uuid: json['uuid'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? 'Unknown',
      thumbnail: json['thumbnail'] ?? json['poster'] ?? json['image'],
      description: json['description'] ?? json['desc'],
    );
  }

  /// Convert MovieSeriesModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'title': title,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (description != null) 'description': description,
    };
  }
}

