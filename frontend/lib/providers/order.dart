import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/cart_provider.dart';
import 'package:dummy_apps/providers/orders.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/screens/payment.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:dummy_apps/widgets/product_offer_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrderFlowNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> placeProductOrder(BuildContext context, Product product) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!context.mounted) return;
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to place an order')),
      );
      return;
    }

    final productsNotifier = ref.read(productProvider.notifier);
    final catalogLoaded = await productsNotifier.fetchProducts(
      syncInventory: false,
    );
    if (!context.mounted) return;
    if (!catalogLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load products. Please try again.'),
        ),
      );
      return;
    }

    Product? currentProduct;
    for (final candidate in ref.read(productProvider)) {
      if (candidate.id == product.id ||
          candidate.sku == product.id ||
          (product.sku != null && candidate.sku == product.sku)) {
        currentProduct = candidate;
        break;
      }
    }
    if (currentProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is no longer available. Refresh the shop.'),
        ),
      );
      return;
    }
    final checkoutProduct = currentProduct;

    var quantity = 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Order ${checkoutProduct.title}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductOfferPrice(product: checkoutProduct),
                  const SizedBox(height: 8),
                  Text('Available Stock: ${checkoutProduct.stock}'),
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
                        onPressed: quantity < checkoutProduct.stock
                            ? () => setState(() => quantity++)
                            : null,
                      ),
                    ],
                  ),
                  if (checkoutProduct.stock == 0)
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
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: checkoutProduct.stock > 0
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Continue to payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !context.mounted) return;
    if (checkoutProduct.stock < quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient stock for ${checkoutProduct.title}. Only ${checkoutProduct.stock} left.',
          ),
        ),
      );
      return;
    }

    try {
      final paymentResult = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => Payment(
            amount: (checkoutProduct.discountedPrice * 100).round() * quantity,
            productId: checkoutProduct.id,
            quantity: quantity,
          ),
        ),
      );

      if (!context.mounted) return;
      if (!_paymentSucceeded(paymentResult)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment was not completed')),
        );
        return;
      }

      await ref
          .read(ordersProvider.notifier)
          .placeOrder(
            checkoutProduct.id,
            quantity,
            paymentIntentId: paymentResult['paymentIntentId'] as String?,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
    }
  }

  Future<void> checkoutCart(BuildContext context) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!context.mounted) return;
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to checkout your cart')),
      );
      return;
    }

    final products = ref.read(productProvider);
    final cart = ref.read(cartProvider);
    final cartItems = products
        .where((product) => cart.any((item) => item.prodId == product.id))
        .map((product) {
          final cartItem = cart.firstWhere((item) => item.prodId == product.id);
          return (product: product, quantity: cartItem.quantity ?? 0);
        })
        .toList();

    if (cartItems.isEmpty) return;

    final insufficientItem = cartItems.where(
      (item) => item.product.stock < item.quantity,
    );
    if (insufficientItem.isNotEmpty) {
      final item = insufficientItem.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient stock for ${item.product.title}. Only ${item.product.stock} items left.',
          ),
        ),
      );
      return;
    }

    final amount = cartItems.fold<int>(
      0,
      (sum, item) =>
          sum + (item.product.discountedPrice * 100).round() * item.quantity,
    );

    if (state) return;
    state = true;

    try {
      final paymentResult = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => Payment(amount: amount, cartCheckout: true),
        ),
      );

      if (!context.mounted) return;
      if (!_paymentSucceeded(paymentResult)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment was not completed')),
        );
        return;
      }

      await ref
          .read(ordersProvider.notifier)
          .placeCartOrder(
            paymentIntentId: paymentResult['paymentIntentId'] as String?,
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart checkout successful!')),
      );
      await ref.read(cartProvider.notifier).fetchCart();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to checkout cart: $e')));
    } finally {
      state = false;
    }
  }

  bool _paymentSucceeded(dynamic result) =>
      result is Map && result['success'] == true;
}

final orderFlowProvider = NotifierProvider<OrderFlowNotifier, bool>(
  OrderFlowNotifier.new,
);
