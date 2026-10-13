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
      if (p is Map<String, dynamic>) {
        return Product.fromJson(p);
      }
      final priceRaw = p['price'];
      final stockRaw = p['stock'];
      final costPriceRaw = p['costPrice'];
      final discountRaw = p['discountPercentage'];
      return Product(
        title: p['title']?.toString() ?? 'Product',
        price: priceRaw is num ? priceRaw.toDouble() : 0,
        costPrice: costPriceRaw is num ? costPriceRaw.toDouble() : 0,
        discountPercentage: discountRaw is num ? discountRaw.toDouble() : 0,
        offerTitle: p['offerTitle']?.toString() ?? '',
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
                'costPrice': p.costPrice,
                'discountPercentage': p.discountPercentage,
                'offerTitle': p.offerTitle,
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

  Future<bool> fetchProducts({bool syncInventory = false}) async {
    try {
      if (syncInventory) {
        await syncInventoryToServer();
      }

      final response = await http.get(Uri.parse('$baseUrl/fetchProducts'));
      final responseData = jsonDecode(response.body);

      if (response.statusCode != 200) {
        return false;
      }

      final List<dynamic> products = responseData['products'] ?? [];
      state = _mapApiProducts(products);
      return true;
    } catch (e) {
      print('Error fetching products (showing local inventory): $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> searchWithPrompt(String prompt) async {
    final url = Uri.parse('$baseUrl/api/assistant');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );

    final responseData = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final message =
          responseData['message'] ?? 'Unable to search products right now.';
      throw Exception(message.toString());
    }

    final List<dynamic> products = responseData['products'] ?? [];
    state = _mapApiProducts(products);

    return responseData;
  }

  Future<bool> addNewProduct(Product product) async {
    try {
      final url = Uri.parse('$baseUrl/api/admin/products');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': product.title,
          'price': product.price,
          'costPrice': product.costPrice,
          'stock': product.stock,
          'imageUrl': product.imageUrl,
          'discountPercentage': product.discountPercentage,
          'offerTitle': product.offerTitle,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['product'] != null) {
          final newProd = Product.fromJson(data['product']);
          state = [...state, newProd];
        } else {
          await fetchProducts(syncInventory: false);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('addNewProduct error: $e');
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final url = Uri.parse('$baseUrl/api/admin/products/${product.id}');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': product.title,
          'price': product.price,
          'costPrice': product.costPrice,
          'stock': product.stock,
          'imageUrl': product.imageUrl,
          'discountPercentage': product.discountPercentage,
          'offerTitle': product.offerTitle,
        }),
      );

      if (response.statusCode == 200) {
        state = state.map((p) => p.id == product.id ? product : p).toList();
        return true;
      }
      return false;
    } catch (e) {
      print('updateProduct error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      final url = Uri.parse('$baseUrl/api/admin/products/$id');
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        state = state.where((p) => p.id != id).toList();
        return true;
      }
      return false;
    } catch (e) {
      print('deleteProduct error: $e');
      return false;
    }
  }

  Future<void> addProduct(Product product) async {
    await addNewProduct(product);
  }
}

final productProvider = NotifierProvider<ProductNotifier, List<Product>>(
  ProductNotifier.new,
);
