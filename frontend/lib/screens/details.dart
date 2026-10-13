import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/cart_provider.dart';
import 'package:dummy_apps/providers/order.dart';
import 'package:dummy_apps/widgets/rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:dummy_apps/widgets/product_offer_price.dart';

class Details extends ConsumerWidget {
  final Product product;
  Details({super.key, required this.product});

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
                  ProductOfferPrice(product: product),
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
                          onPressed: () => ref
                              .read(orderFlowProvider.notifier)
                              .placeProductOrder(context, product),
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
