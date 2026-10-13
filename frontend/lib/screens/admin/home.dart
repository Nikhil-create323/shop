import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/admin_provider.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/screens/admin/dashboard.dart';
import 'package:dummy_apps/screens/admin/discounts_offers.dart';
import 'package:dummy_apps/screens/admin/returns.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  int _returnsRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(productProvider.notifier).fetchProducts(syncInventory: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const AdminInventoryView(),
      const DiscountsOffersScreen(),
      const DashboardScreen(),
      ReturnsScreen(key: ValueKey(_returnsRefreshKey)),
    ];

    final titles = [
      'Inventory Management',
      'Discounts & Offers',
      'Analytics Dashboard',
      'Return Requests',
    ];

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(titles[_selectedIndex]),
        actions: [
          if (_selectedIndex != 1)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (_selectedIndex == 0) {
                  ref.read(productProvider.notifier).fetchProducts(syncInventory: false);
                } else if (_selectedIndex == 2) {
                  ref.read(adminDashboardProvider.notifier).fetchStats();
                } else {
                  setState(() => _returnsRefreshKey++);
                }
              },
              tooltip: 'Refresh',
            ),
        ],
      ),
      drawer: AppDrawer(),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            ref.read(productProvider.notifier).fetchProducts(syncInventory: false);
          } else if (index == 2) {
            ref.read(adminDashboardProvider.notifier).fetchStats();
          } else if (index == 3) {
            setState(() => _returnsRefreshKey++);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products & Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Discounts & Offers',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_return_outlined),
            selectedIcon: Icon(Icons.assignment_return),
            label: 'Returns',
          ),
        ],
      ),
    );
  }
}

class AdminInventoryView extends ConsumerStatefulWidget {
  const AdminInventoryView({super.key});

  @override
  ConsumerState<AdminInventoryView> createState() => _AdminInventoryViewState();
}

class _AdminInventoryViewState extends ConsumerState<AdminInventoryView> {
  Future<void> _showAddProductDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final stockController = TextEditingController(text: '10');
    final imageUrlController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Product Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Selling Price (₹)',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          validator: (v) => v == null || double.tryParse(v) == null ? 'Valid price' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: costPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cost Price (₹)',
                            prefixIcon: Icon(Icons.receipt),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Initial Stock',
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    validator: (v) => v == null || int.tryParse(v) == null ? 'Valid stock' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                      prefixIcon: Icon(Icons.image),
                      hintText: 'https://...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Add Product'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final newProduct = Product(
      id: '',
      title: titleController.text.trim(),
      price: double.parse(priceController.text),
      costPrice: double.tryParse(costPriceController.text) ?? 0.0,
      stock: int.parse(stockController.text),
      imageUrl: imageUrlController.text.trim().isNotEmpty
          ? imageUrlController.text.trim()
          : 'https://images.unsplash.com/photo-1523275335684-37898b6baf30',
    );

    final success = await ref.read(productProvider.notifier).addNewProduct(newProduct);
    if (!mounted) return;

    if (success) {
      await ref.read(adminDashboardProvider.notifier).fetchStats();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newProduct.title} added successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add product.')),
      );
    }
  }

  Future<void> _confirmDeleteProduct(BuildContext context, Product product) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text('Are you sure you want to remove "${product.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final success = await ref.read(productProvider.notifier).deleteProduct(product.id);
    if (!mounted) return;

    if (success) {
      await ref.read(adminDashboardProvider.notifier).fetchStats();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${product.title}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove product.')),
      );
    }
  }

  Future<void> _updateStock(Product product, int delta) async {
    final newStock = (product.stock + delta) < 0 ? 0 : (product.stock + delta);
    final updated = product.copyWith(stock: newStock);
    final success = await ref.read(productProvider.notifier).updateProduct(updated);
    if (!mounted) return;
    if (success) {
      await ref.read(adminDashboardProvider.notifier).fetchStats();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update stock. Please retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

            int crossAxisCount = 1;
            if (width > 1200) {
              crossAxisCount = 4;
            } else if (width > 800) {
              crossAxisCount = 3;
            } else if (width > 500 || isLandscape) {
              crossAxisCount = 2;
            }

            if (products.isEmpty) {
              return const Center(
                child: Text('No products in inventory.', style: TextStyle(fontSize: 18)),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: width > 700 ? 0.65 : 0.52,
              ),
              itemBuilder: (context, index) {
                final prod = products[index];

                return Material(
                  borderRadius: BorderRadius.circular(20),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PRODUCT IMAGE WITH STOCK BADGE
                        Expanded(
                          flex: 5,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: prod.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    errorWidget: (context, url, error) => const Center(
                                      child: Icon(Icons.image_not_supported, size: 48),
                                    ),
                                  ),
                                ),
                              ),
                              if (prod.discountPercentage > 0)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.error,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${prod.discountPercentage.toStringAsFixed(0)}% OFF',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(0.6),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () => _confirmDeleteProduct(context, prod),
                                  tooltip: 'Remove Product',
                                ),
                              ),
                            ],
                          ),
                        ),

                        // PRODUCT DETAILS & STOCK CONTROLS
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  prod.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "₹ ${prod.discountedPrice}",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (prod.discountPercentage > 0)
                                          Text(
                                            "₹ ${prod.price}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              decoration: TextDecoration.lineThrough,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: prod.stock > 0
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Stock: ${prod.stock}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: prod.stock > 0
                                              ? Theme.of(context).colorScheme.onPrimaryContainer
                                              : Theme.of(context).colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // QUICK STOCK ADJUSTMENT BUTTONS
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 18),
                                        onPressed: prod.stock > 0 ? () => _updateStock(prod, -1) : null,
                                        tooltip: 'Decrease Stock',
                                      ),
                                      Text(
                                        'Stock',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: () => _updateStock(prod, 1),
                                        tooltip: 'Increase Stock',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
