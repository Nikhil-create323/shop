import 'dart:convert';

import 'package:dummy_apps/model/order.dart';
import 'package:dummy_apps/providers/cart_provider.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:dummy_apps/main.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() => [];

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _ensureLoggedIn() async {
    if (!await AuthService.isLoggedIn()) {
      throw Exception('Please login to continue');
    }
  }

  Future<void> placeOrder(String productId, int quantity, {String? paymentIntentId}) async {
    await _ensureLoggedIn();

    final url = Uri.parse('$baseUrl/placeOrder');
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'productId': productId,
        'quantity': quantity,
        if (paymentIntentId != null) 'paymentIntentId': paymentIntentId,
      }),
    );

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      final orderJson = responseData['order'] as Map<String, dynamic>;
      final newOrder = Order.fromJson(orderJson);

      state = [newOrder, ...state];

      await ref.read(productProvider.notifier).fetchProducts(syncInventory: false);

      final cartJson = responseData['cart'] as List<dynamic>?;
      ref.read(cartProvider.notifier).syncFromServerCart(cartJson);
    } else {
      final message = responseData['message'] ?? response.body;
      throw Exception(message);
    }
  }

  Future<void> placeCartOrder({String? paymentIntentId}) async {
    await _ensureLoggedIn();
    final url = Uri.parse('$baseUrl/placeCartOrder');
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({ if (paymentIntentId != null) 'paymentIntentId': paymentIntentId }),
    );

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      final List<dynamic> ordersJson = responseData['orders'] ?? [];
      final newOrders = ordersJson
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();

      state = [...newOrders, ...state];

      await ref.read(productProvider.notifier).fetchProducts(syncInventory: false);

      final cartJson = responseData['cart'] as List<dynamic>?;
      ref.read(cartProvider.notifier).syncFromServerCart(cartJson);
    } else {
      final message = responseData['message'] ?? response.body;
      throw Exception('Failed to checkout cart: $message');
    }
  }

  Future<void> fetchOrders() async {
    await _ensureLoggedIn();
    final url = Uri.parse('$baseUrl/fetchOrders');
    final response = await http.get(url, headers: await _headers());

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> ordersData = responseData['orders'] ?? [];

      state = ordersData
          .map((orderJson) => Order.fromJson(orderJson as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch orders: ${response.body}');
    }
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);
