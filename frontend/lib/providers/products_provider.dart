import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/widgets/inventory.dart';
import 'package:dummy_apps/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProductNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() => List<Product>.from(inventory);

  List<Product> _mapApiProducts(List<dynamic> products) {
    return products.map((p) {
      final priceRaw = p['price'];
      final stockRaw = p['stock'];
      return Product(
        title: p['title']?.toString() ?? 'Product',
        price: priceRaw is num ? priceRaw.toDouble() : 0,
        imageUrl: p['imageUrl']?.toString() ?? '',
        id: (p['_id'] ?? p['id']).toString(),
        stock: stockRaw is num ? stockRaw.toInt() : 10,
      );
    }).toList();
  }

  Future<void> syncInventoryToServer() async {
    final url = Uri.parse('$baseUrl/seedProducts');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'products': inventory
            .map(
              (p) => {
                'sku': p.id,
                'title': p.title,
                'price': p.price,
                'imageUrl': p.imageUrl,
                'stock': p.stock,
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode != 200) {
      print('seedProducts failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> fetchProducts({bool syncInventory = true}) async {
    try {
      if (syncInventory) {
        await syncInventoryToServer();
      }

      final response = await http.get(Uri.parse('$baseUrl/fetchProducts'));
      final responseData = jsonDecode(response.body);
      // print('fetchProducts response: $responseData');

      if (response.statusCode != 200) {
        // print('fetchProducts status: ${response.statusCode}');
        return;
      }

      final List<dynamic> products = responseData['products'] ?? [];
      if (products.isEmpty) return;

      state = _mapApiProducts(products);
    } catch (e) {
      print('Error fetching products (showing local inventory): $e');
    }
  }

  Future<Map<String, dynamic>> searchWithPrompt(String prompt) async {
    final url = Uri.parse('$baseUrl/api/assistant');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final message = responseData['message'] ?? response.body;
      throw Exception('Search failed: $message');
    }

    final List<dynamic> products = responseData['products'] ?? [];
    state = _mapApiProducts(products);

    return responseData;
  }

  Future<void> addProduct(Product product) async {
    final url = Uri.parse('$baseUrl/seedProducts');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'products': [
          {
            'sku': product.id,
            'title': product.title,
            'price': product.price,
            'imageUrl': product.imageUrl,
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      await fetchProducts();
    } else {
      print('${response.statusCode} , ${response.body}');
    }
  }
}

final productProvider = NotifierProvider<ProductNotifier, List<Product>>(
  ProductNotifier.new,
);
