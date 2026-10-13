class Rating {
  String? id;
  double rating;
  String productId;
  String user;
  String description;
  int likeCount;
  int dislikeCount;
  List<String> likedBy;
  List<String> dislikedBy;
  DateTime timestamp;

  Rating({
    this.id,
    required this.rating,
    required this.productId,
    required this.user,
    required this.description,
    required this.likeCount,
    required this.dislikeCount,
    required this.likedBy,
    required this.dislikedBy,
    required this.timestamp,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: (json['_id'] ?? json['id'])?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      productId: json['productId']?.toString() ?? '',
      user: json['user']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      dislikeCount: (json['dislikeCount'] as num?)?.toInt() ?? 0,
      likedBy: (json['likedBy'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      dislikedBy: (json['dislikedBy'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rating': rating,
      'productId': productId,
      'user': user,
      'description': description,
      'likeCount': likeCount,
      'dislikeCount': dislikeCount,
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
