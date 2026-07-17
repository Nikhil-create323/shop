import 'dart:async';

import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/screens/details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dummy_apps/widgets/drawer.dart';

class ProductSearch extends ConsumerStatefulWidget {
  const ProductSearch({super.key});

  @override
  ConsumerState<ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends ConsumerState<ProductSearch> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        searchQuery = value;
      });
    });
  }

  List<Product> _getFilteredProducts(String searchQuery) {
    final products = ref.watch(productProvider);

    final filteredProductsStartingWithQuery = products.where((product) {
      final title = product.title.toLowerCase();
      final query = searchQuery.toLowerCase();

      return title.startsWith(query);
    }).toList();

    final filteredProductsContainingQuery = products.where((product) {
      final title = product.title.toLowerCase();
      final query = searchQuery.toLowerCase();

      return title.contains(query) && !title.startsWith(query);
    }).toList();

    return filteredProductsStartingWithQuery + filteredProductsContainingQuery;
  }

  @override
  Widget build(BuildContext context) {
    // final products = ref.watch(productProvider);

    // Prefix filter
    // final filteredProducts = products.where((product) {
    //   final title = product.title.toLowerCase();
    //   final query = searchQuery.toLowerCase();

    //   return title.startsWith(query);
    // }).toList();
    final filteredProducts = _getFilteredProducts(searchQuery);
    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search products...',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();

                setState(() {
                  searchQuery = '';
                });
              },
            ),
        ],
      ),
      body: filteredProducts.isEmpty
          ? const Center(child: Text('No matching products found'))
          : ListView.builder(
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final Product prod = filteredProducts[index];

                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => Details(product: prod)),
                    );
                  },

                  leading: prod.imageUrl.isNotEmpty
                      ? Image.network(
                          prod.imageUrl,
                          width: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported),
                        )
                      : const Icon(Icons.shopping_bag),

                  title: Text(prod.title),

                  subtitle: Text('₹ ${prod.price}'),
                );
              },
            ),
    );
  }
}
