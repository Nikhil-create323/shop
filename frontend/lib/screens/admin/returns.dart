import 'dart:convert';

import 'package:dummy_apps/main.dart';
import 'package:dummy_apps/providers/admin_provider.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRequests);
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/return-requests'),
        headers: await _headers(),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(data['message'] ?? 'Failed to load return requests');
      }
      _requests = (data['orders'] as List<dynamic>? ?? [])
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decideReturn(String orderId, String decision) async {
    setState(() => _processing.add(orderId));
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/return-requests/$orderId'),
        headers: await _headers(),
        body: jsonEncode({'decision': decision}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(data['message'] ?? 'Could not update the return');
      }
      await _loadRequests();
      if (decision == 'approve') {
        await ref.read(productProvider.notifier).fetchProducts(syncInventory: false);
        await ref.read(adminDashboardProvider.notifier).fetchStats();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Return updated')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Return update failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(child: Text(_error!, textAlign: TextAlign.center)),
              ],
            )
          : _requests.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No return requests')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final order = _requests[index];
                final orderId = order['_id'].toString();
                final busy = _processing.contains(orderId);
                final title = order['title']?.toString() ?? 'Product';
                final quantity = (order['quantity'] as num?)?.toInt() ?? 0;
                final price = (order['price'] as num?)?.toDouble() ?? 0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Quantity: $quantity'),
                        Text(
                          'Refund: ₹${(price * quantity).toStringAsFixed(2)}',
                        ),
                        Text('Order ID: $orderId'),
                        const SizedBox(height: 12),
                        if (busy)
                          const Center(child: CircularProgressIndicator())
                        else
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _decideReturn(orderId, 'approve'),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve & refund'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _decideReturn(orderId, 'reject'),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ],
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
