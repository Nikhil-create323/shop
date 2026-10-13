import 'package:dummy_apps/model/rating.dart';

class Product {
  final String id;
  final String? sku;
  final String title;
  final String imageUrl;
  final double price;
  final double costPrice;
  final double discountPercentage;
  final String offerTitle;
  final int stock;
  List<Rating> ratings;

  Product({
    required this.id,
    this.sku,
    required this.title,
    required this.imageUrl,
    required this.price,
    this.costPrice = 0.0,
    this.discountPercentage = 0.0,
    this.offerTitle = '',
    this.stock = 10,
    List<Rating>? ratings,
  }) : ratings = ratings ?? [];

  double get discountedPrice {
    if (discountPercentage <= 0) return price;
    final discounted = price * (1 - (discountPercentage / 100));
    return discounted > 0 ? double.parse(discounted.toStringAsFixed(2)) : 0.0;
  }

  Product copyWith({
    String? id,
    String? sku,
    String? title,
    String? imageUrl,
    double? price,
    double? costPrice,
    double? discountPercentage,
    String? offerTitle,
    int? stock,
    List<Rating>? ratings,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      offerTitle: offerTitle ?? this.offerTitle,
      stock: stock ?? this.stock,
      ratings: ratings ?? this.ratings,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      sku: json['sku']?.toString(),
      title: json['title']?.toString() ?? 'Product',
      imageUrl: json['imageUrl']?.toString() ?? '',
      price: (json['price'] ?? 0).toDouble(),
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      discountPercentage: (json['discountPercentage'] ?? 0).toDouble(),
      offerTitle: json['offerTitle']?.toString() ?? '',
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
      if (sku != null) 'sku': sku,
      'title': title,
      'imageUrl': imageUrl,
      'price': price,
      'costPrice': costPrice,
      'discountPercentage': discountPercentage,
      'offerTitle': offerTitle,
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
