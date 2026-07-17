import 'package:dummy_apps/model/cart.dart';
import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dummy_apps/utils/auth-service.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void _applyCartData(dynamic responseData) {
    final List<dynamic> items =
        (responseData is Map ? responseData['data'] : null) ??
        (responseData is List ? responseData : <dynamic>[]);

    state = items
        .map((itemData) => CartItem.fromJson(itemData as Map<String, dynamic>))
        .toList();
  }

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

  Future<void> fetchCart() async {
    await _ensureLoggedIn();
    final url = Uri.parse('$baseUrl/fetchCart');
    final response = await http.get(url, headers: await _headers());

    if (response.statusCode == 200) {
      _applyCartData(jsonDecode(response.body));
    } else {
      throw Exception('Server returned status: ${response.statusCode}');
    }
  }

  Future<void> addToCart(Product product) async {
    await _ensureLoggedIn();
    final url = Uri.parse('$baseUrl/addToCart');
    final item = CartItem(prodId: product.id, quantity: 1, user: null);

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(item.toJson()),
    );

    if (response.statusCode == 200) {
      _applyCartData(jsonDecode(response.body));
    } else {
      throw Exception(
        'Could not add to cart: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> removeFromCart(String productId, {bool removeAll = true}) async {
    await _ensureLoggedIn();
    final url = Uri.parse('$baseUrl/removeFromCart');
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({'prodId': productId, 'removeAll': removeAll}),
    );

    if (response.statusCode == 200) {
      _applyCartData(jsonDecode(response.body));
    } else {
      throw Exception(
        'Could not remove from cart: ${response.statusCode} ${response.body}',
      );
    }
  }

  void syncFromServerCart(List<dynamic>? cartJson) {
    if (cartJson == null) return;
    state = cartJson
        .map((itemData) => CartItem.fromJson(itemData as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearCart() async {
    await _ensureLoggedIn();
    final url = '$baseUrl/clearCart';
    final response = await http.post(
      Uri.parse(url),
      headers: await _headers(),
      body: jsonEncode({'user': 'userId'}),
    );

    if (response.statusCode == 200) {
      state = [];
    } else {
      throw Exception(
        'Could not clear cart: ${response.statusCode} ${response.body}',
      );
    }
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);
