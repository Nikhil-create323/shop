import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscountsOffersScreen extends ConsumerStatefulWidget {
  final Product? initialProduct;

  const DiscountsOffersScreen({super.key, this.initialProduct});

  @override
  ConsumerState<DiscountsOffersScreen> createState() => _DiscountsOffersScreenState();
}

class _DiscountsOffersScreenState extends ConsumerState<DiscountsOffersScreen> {
  final _formKey = GlobalKey<FormState>();

  Product? _selectedProduct;
  late TextEditingController _discountController;
  late TextEditingController _offerTitleController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockController;
  late TextEditingController _priceController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;

    _discountController = TextEditingController(
      text: _selectedProduct?.discountPercentage.toStringAsFixed(0) ?? '0',
    );
    _offerTitleController = TextEditingController(
      text: _selectedProduct?.offerTitle ?? '',
    );
    _costPriceController = TextEditingController(
      text: _selectedProduct?.costPrice.toStringAsFixed(2) ?? '0.00',
    );
    _stockController = TextEditingController(
      text: _selectedProduct?.stock.toString() ?? '10',
    );
    _priceController = TextEditingController(
      text: _selectedProduct?.price.toStringAsFixed(2) ?? '0.00',
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    _offerTitleController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onProductSelected(Product? product) {
    setState(() {
      _selectedProduct = product;
      if (product != null) {
        _discountController.text = product.discountPercentage.toStringAsFixed(0);
        _offerTitleController.text = product.offerTitle;
        _costPriceController.text = product.costPrice.toStringAsFixed(2);
        _stockController.text = product.stock.toString();
        _priceController.text = product.price.toStringAsFixed(2);
      }
    });
  }

  Future<void> _submitForm() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product first.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
    final stock = int.tryParse(_stockController.text) ?? _selectedProduct!.stock;
    final price = double.tryParse(_priceController.text) ?? _selectedProduct!.price;

    final updatedProduct = _selectedProduct!.copyWith(
      price: price,
      costPrice: costPrice,
      discountPercentage: discount,
      offerTitle: _offerTitleController.text.trim(),
      stock: stock,
    );

    final success = await ref
        .read(productProvider.notifier)
        .updateProduct(updatedProduct);

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Discount & Offer updated for ${updatedProduct.title}!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update product discount.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider);

    // If initialProduct was set or selected product matches, find current reference
    if (_selectedProduct != null && products.isNotEmpty) {
      final currentMatch = products.where((p) => p.id == _selectedProduct!.id).firstOrNull;
      if (currentMatch != null && currentMatch != _selectedProduct) {
        _selectedProduct = currentMatch;
      }
    }

    // Products with active discounts or offers
    final activeOffers = products.where((p) => p.discountPercentage > 0 || p.offerTitle.isNotEmpty).toList();

    double origPrice = double.tryParse(_priceController.text) ?? _selectedProduct?.price ?? 0.0;
    double discPct = double.tryParse(_discountController.text) ?? 0.0;
    double effectivePrice = origPrice > 0 && discPct > 0
        ? origPrice * (1 - (discPct / 100))
        : origPrice;
    double unitCost = double.tryParse(_costPriceController.text) ?? 0.0;
    double unitProfit = effectivePrice - unitCost;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Discounts & Offers',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Apply price reductions, special offer banners, and cost prices',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // FORM CARD
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SELECT PRODUCT DROPDOWN
                        DropdownButtonFormField<Product>(
                          initialValue: products.contains(_selectedProduct) ? _selectedProduct : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Product',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: products.map((p) {
                            return DropdownMenuItem<Product>(
                              value: p,
                              child: Text(
                                '${p.title} (₹${p.price})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _onProductSelected,
                        ),
                        const SizedBox(height: 16),

                        if (_selectedProduct != null) ...[
                          // LIVE PREVIEW CARD
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: _selectedProduct!.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedProduct!.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (discPct > 0) ...[
                                            Text(
                                              '₹${origPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                decoration: TextDecoration.lineThrough,
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            '₹${effectivePrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          if (discPct > 0) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.error,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${discPct.toStringAsFixed(0)}% OFF',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Estimated Unit Profit: ₹${unitProfit.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: unitProfit >= 0 ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // SELLING PRICE & COST PRICE
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Selling Price (₹)',
                                    prefixIcon: const Icon(Icons.attach_money),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    if (v == null || double.tryParse(v) == null) {
                                      return 'Enter valid price';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _costPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Cost Price (₹)',
                                    prefixIcon: const Icon(Icons.receipt),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // DISCOUNT % & STOCK
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _discountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Discount %',
                                    prefixIcon: const Icon(Icons.percent),
                                    suffixText: '%',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final d = double.tryParse(v ?? '');
                                    if (d == null || d < 0 || d > 100) {
                                      return '0 to 100%';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _stockController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Available Stock',
                                    prefixIcon: const Icon(Icons.inventory_sharp),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // OFFER TITLE / PROMO TAG
                          TextFormField(
                            controller: _offerTitleController,
                            decoration: InputDecoration(
                              labelText: 'Offer Title / Promo Tag (Optional)',
                              hintText: 'e.g. Clearance Sale, Buy 1 Get 1',
                              prefixIcon: const Icon(Icons.local_offer_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // SUBMIT BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                _isSaving ? 'Updating...' : 'Save Discount & Offer',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ACTIVE OFFERS LIST
              Text(
                'Active Special Offers (${activeOffers.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              if (activeOffers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No active discounts or special offers configured.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeOffers.length,
                  itemBuilder: (context, index) {
                    final item = activeOffers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '₹${item.discountedPrice}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                if (item.discountPercentage > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${item.discountPercentage.toStringAsFixed(0)}% OFF',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (item.offerTitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Offer: ${item.offerTitle}',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_note),
                          onPressed: () => _onProductSelected(item),
                          tooltip: 'Edit Offer',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
