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
      rating: (json['rating'] as num).toDouble(),
      productId: json['productId'] as String,
      user: json['user'] as String,
      description: json['description'] as String,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      dislikeCount: (json['dislikeCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      dislikedBy: List<String>.from(json['dislikedBy'] ?? []),
      timestamp: DateTime.parse(json['timestamp']),
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
