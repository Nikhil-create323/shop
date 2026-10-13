import 'package:dummy_apps/model/order.dart';
import 'package:dummy_apps/providers/orders.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dummy_apps/widgets/drawer.dart';

class Orders extends ConsumerStatefulWidget {
  const Orders({super.key});

  @override
  ConsumerState<Orders> createState() => _OrdersState();
}

class _OrdersState extends ConsumerState<Orders> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadOrders);
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(ordersProvider.notifier).fetchOrders();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayTitle(Order order) {
    if (order.title.isNotEmpty) return order.title;
    final products = ref.read(productProvider);
    final match = products.where((p) => p.id == order.productId);
    if (match.isNotEmpty) return match.first.title;
    return 'Product ${order.productId}';
  }

  Future<void> _updateOrder(Order order, {required bool cancel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(cancel ? 'Cancel order?' : 'Request a return?'),
        content: Text(
          cancel
              ? 'The payment will be refunded and the item returned to inventory.'
              : 'An admin must approve the return before a refund and restock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(cancel ? 'Cancel order' : 'Request return'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (cancel) {
        await ref.read(ordersProvider.notifier).cancelOrder(order.id);
      } else {
        await ref.read(ordersProvider.notifier).requestReturn(order.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cancel ? 'Order cancelled and refunded' : 'Return request submitted'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Your Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadOrders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadOrders,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : orders.isEmpty
          ? const Center(child: Text('No orders yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final title = _displayTitle(order);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: order.imageUrl.isNotEmpty
                        ? Image.network(
                            order.imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.shopping_bag, size: 40),
                          )
                        : const Icon(Icons.shopping_bag, size: 40),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Qty: ${order.quantity}'),
                        Text(
                          'Price at order: ₹${order.price.toStringAsFixed(2)} each',
                        ),
                        Text(
                          'Line total: ₹${order.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (order.orderedAt != null)
                          Text(
                            'Ordered: ${order.orderedAt!.toLocal().toString().split('.').first}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: ${order.status.replaceAll('_', ' ')}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (order.status == 'placed')
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () => _updateOrder(order, cancel: true),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel order'),
                              ),
                              TextButton.icon(
                                onPressed: () => _updateOrder(order, cancel: false),
                                icon: const Icon(Icons.assignment_return_outlined),
                                label: const Text('Request return'),
                              ),
                            ],
                          )
                        else if (order.status == 'return_rejected')
                          TextButton.icon(
                            onPressed: () => _updateOrder(order, cancel: false),
                            icon: const Icon(Icons.assignment_return_outlined),
                            label: const Text('Request return again'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
