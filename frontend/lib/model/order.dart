class Order {
  final String id;
  final String productId;
  final String title;
  final String imageUrl;
  final int quantity;
  final double price;
  final DateTime? orderedAt;

  Order({
    required this.id,
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    this.orderedAt,
  });

  double get lineTotal => price * quantity;

  factory Order.fromJson(Map<String, dynamic> json) {
    final quantityRaw = json['quantity'];
    final priceRaw = json['price'];

    return Order(
      id: (json['_id'] ?? json['id']).toString(),
      productId: json['productId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Product',
      imageUrl: json['imageUrl']?.toString() ?? '',
      quantity: quantityRaw is num ? quantityRaw.toInt() : 1,
      price: priceRaw is num ? priceRaw.toDouble() : 0,
      orderedAt: json['orderedAt'] != null
          ? DateTime.tryParse(json['orderedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'title': title,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'price': price,
      if (orderedAt != null) 'orderedAt': orderedAt!.toIso8601String(),
    };
  }
}
