import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/cart_provider.dart';
import 'package:dummy_apps/providers/order.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:dummy_apps/widgets/product_offer_price.dart';

class CartViewItem {
  final Product product;
  final int quantity;

  const CartViewItem({required this.product, required this.quantity});
}

class CartWidget extends ConsumerStatefulWidget {
  const CartWidget({super.key});

  @override
  ConsumerState<CartWidget> createState() => _CartWidgetState();
}

class _CartWidgetState extends ConsumerState<CartWidget> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).fetchCart());
  }

  Future<void> _removeFromCart(String productId) async {
    try {
      await ref
          .read(cartProvider.notifier)
          .removeFromCart(productId, removeAll: true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product removed from cart')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error removing product: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider);
    final cart = ref.watch(cartProvider);
    final isOrdering = ref.watch(orderFlowProvider);

    final cartItems = products
        .where((product) => cart.any((item) => item.prodId == product.id))
        .map((product) {
          final cartItem = cart.firstWhere((item) => item.prodId == product.id);

          return CartViewItem(
            product: product,
            quantity: cartItem.quantity ?? 0,
          );
        })
        .toList();

    final cartTotal = cartItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.product.discountedPrice * item.quantity),
    );

    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Cart'),
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text('Cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: cartItems.length + 1,
                    itemBuilder: (context, index) {
                      if (index == cartItems.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Cart total (current prices): ₹${cartTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: cartItems.isEmpty || isOrdering
                                    ? null
                                    : () => ref
                                          .read(orderFlowProvider.notifier)
                                          .checkoutCart(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Place Cart Order'),
                              ),
                            ],
                          ),
                        );
                      }

                      final item = cartItems[index];
                      final product = item.product;
                      final quantity = item.quantity;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Image.network(
                                product.imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ProductOfferPrice(product: product, compact: true),
                                    Text('Quantity: $quantity'),
                                    Text(
                                      'Line total: ₹${(product.discountedPrice * quantity).toStringAsFixed(2)}',
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () =>
                                        _removeFromCart(product.id),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                    ),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
