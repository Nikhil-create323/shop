// import 'package:flutter/material.dart';
class CartItem {
  String? prodId;
  int? quantity;
  var user;

  CartItem({this.prodId, this.quantity, this.user});

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      prodId: json['prodId']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt(),
      user: json['user'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'prodId': prodId, 'quantity': quantity, 'user': user};
  }
}
