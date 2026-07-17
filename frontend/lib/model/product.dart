import 'package:dummy_apps/model/rating.dart';

class Product {
  final String id;
  final String title;
  final String imageUrl;
  final double price;
  final int stock;
  List<Rating> ratings;

  Product({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.price,
    this.stock = 10,
    List<Rating>? ratings,
  }) : ratings = ratings ?? [];

  // --- THIS IS THE DECLARATION ---
  // It's a 'factory' constructor. It takes a Map and returns a Product object.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? (json['_id'] ?? '').toString(),
      title: json['title'] ?? 'Product',
      imageUrl: json['imageUrl'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 10,
      ratings: (json['ratings'] as List<dynamic>?)
              ?.map((e) => Rating.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'price': price,
      'stock': stock,
      'ratings': ratings.map((e) => e.toJson()).toList(),
    };
  }

  double get averageRating {
    if (ratings.isEmpty) return 0.0;
    return ratings.map((r) => r.rating).reduce((a, b) => a + b) /
        ratings.length;
  }

  int get totalRatings => ratings.length;
}
