import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/screens/Auth.dart';
import 'package:dummy_apps/screens/Shop.dart';
import 'package:dummy_apps/screens/cart.dart';
import 'package:dummy_apps/screens/details.dart';
import 'package:dummy_apps/screens/orders.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:dummy_apps/widgets/product_offer_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({
    super.key,
    required this.query,
    required this.products,
  });

  final String query;
  final List<Product> products;

  Future<void> _handleMenuSelection(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    switch (value) {
      case 'home':
        await ref.read(productProvider.notifier).fetchProducts();
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Shop()),
        );
        break;
      case 'cart':
        if (!await AuthService.isLoggedIn()) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to view cart')),
          );
          return;
        }
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartWidget()),
        );
        break;
      case 'orders':
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Orders()),
        );
        break;
      case 'account':
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
        break;
      case 'logout':
        await AuthService.clear();
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Shop()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await ref.read(productProvider.notifier).fetchProducts();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Results for "$query"'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await ref.read(productProvider.notifier).fetchProducts();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuSelection(context, ref, value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'home', child: Text('Home')),
                PopupMenuItem(value: 'cart', child: Text('Cart')),
                PopupMenuItem(value: 'orders', child: Text('Orders')),
                PopupMenuItem(value: 'account', child: Text('Account')),
              ],
            ),
          ],
        ),
        body: products.isEmpty
            ? const Center(child: Text('No matching products found'))
            : ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];

                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Details(product: product),
                        ),
                      );
                    },
                    leading: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            width: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported),
                          )
                        : const Icon(Icons.shopping_bag),
                    title: Text(product.title),
                    subtitle: ProductOfferPrice(product: product, compact: true),
                  );
                },
              ),
      ),
    );
  }
}
