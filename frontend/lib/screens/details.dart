import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/cart_provider.dart';
import 'package:dummy_apps/providers/orders.dart';
import 'package:dummy_apps/screens/payment.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:dummy_apps/widgets/rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dummy_apps/widgets/drawer.dart';

class Details extends ConsumerWidget {
  final Product product;
  Details({super.key, required this.product});

  Future<void> _showOrderDialog(BuildContext context, WidgetRef ref) async {
    if (!await AuthService.isLoggedIn()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to place an order')),
      );
      return;
    }

    int quantity = 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Order ${product.title}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Price: ₹${product.price}'),
                  const SizedBox(height: 8),
                  Text('Available Stock: ${product.stock}'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: quantity < product.stock
                            ? () => setState(() => quantity++)
                            : null,
                      ),
                    ],
                  ),
                  if (product.stock == 0)
                    Text(
                      'Out of stock',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: product.stock > 0
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Continue to payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    if (product.stock < quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient stock for ${product.title}. Only ${product.stock} left.',
          ),
        ),
      );
      return;
    }

    final paymentResult = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) =>
            Payment(amount: (product.price * quantity * 100).round()),
      ),
    );

    if (paymentResult == null ||
        paymentResult is! Map ||
        paymentResult['success'] != true) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment was not completed')),
      );
      return;
    }

    final paymentIntentId = paymentResult['paymentIntentId'] as String?;

    try {
      await ref
          .read(ordersProvider.notifier)
          .placeOrder(product.id, quantity, paymentIntentId: paymentIntentId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(product.title),
      ),
      body: Container(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ListView(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      product.imageUrl,
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 280,
                        child: Icon(Icons.image_not_supported, size: 64),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹ ${product.price}',
                    style: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Available Quantity: ${product.stock}',
                    style: TextStyle(
                      fontSize: 16,
                      color: product.stock > 0
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 20),
                  RatingWidget(product: product),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(cartProvider.notifier).addToCart(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added to cart'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('add to cart'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showOrderDialog(context, ref),
                          child: const Text('order item'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
