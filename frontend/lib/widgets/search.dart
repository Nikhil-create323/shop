import 'dart:async';

import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/screens/Auth.dart';
import 'package:dummy_apps/screens/Shop.dart';
import 'package:dummy_apps/screens/cart.dart';
import 'package:dummy_apps/screens/orders.dart';
import 'package:dummy_apps/screens/search-result.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        searchQuery = value.trim();
      });
    });
  }

  List<Product> _getSuggestions(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return const [];

    final products = ref.watch(productProvider);
    final lowerQuery = trimmedQuery.toLowerCase();

    final startsWith = products.where((product) {
      final title = product.title.toLowerCase();
      return title.startsWith(lowerQuery);
    }).toList();

    final contains = products.where((product) {
      final title = product.title.toLowerCase();
      return title.contains(lowerQuery) && !title.startsWith(lowerQuery);
    }).toList();

    return [...startsWith, ...contains];
  }

  void _submitSearch([String? explicitQuery]) {
    final query = (explicitQuery ?? _controller.text).trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    final filteredProducts = _getSuggestions(query);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SearchResultsScreen(query: query, products: filteredProducts),
      ),
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case 'home':
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submitSearch(),
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
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _submitSearch(),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'home', child: Text('Home')),
              PopupMenuItem(value: 'cart', child: Text('Cart')),
              PopupMenuItem(value: 'orders', child: Text('Orders')),
              PopupMenuItem(value: 'account', child: Text('Account')),
            ],
          ),
        ],
      ),
      body: searchQuery.isEmpty
          ? const Center(child: Text('Type a product name and press search'))
          : _buildSuggestions(),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _getSuggestions(searchQuery);

    if (suggestions.isEmpty) {
      return const Center(child: Text('No matching products found'));
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final product = suggestions[index];

        return ListTile(
          leading: product.imageUrl.isNotEmpty
              ? Image.network(
                  product.imageUrl,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported),
                )
              : const Icon(Icons.shopping_bag),
          title: Text(product.title),
          subtitle: Text('₹ ${product.price}'),
          onTap: () {
            _controller.text = product.title;
            _submitSearch(product.title);
          },
        );
      },
    );
  }
}
