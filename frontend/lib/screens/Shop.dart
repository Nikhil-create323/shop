import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/providers/order.dart';
import 'package:dummy_apps/providers/cart_provider.dart';
import 'package:dummy_apps/model/product.dart';
import 'package:dummy_apps/screens/details.dart';
import 'package:dummy_apps/utils/auth-service.dart';
import 'package:dummy_apps/widgets/assistant.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:dummy_apps/widgets/product_offer_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

const storage = FlutterSecureStorage();

class Shop extends ConsumerStatefulWidget {
  @override
  ConsumerState<Shop> createState() {
    return _Shop();
  }
}

class _Shop extends ConsumerState<Shop> {
  Future<void> _addToCart(BuildContext context, Product prod) async {
    try {
      var token = await storage.read(key: "token");

      if (token == null || !await AuthService.isLoggedIn()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add items to cart')),
        );

        return;
      }

      await ref.read(cartProvider.notifier).addToCart(prod);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${prod.title} to cart'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login required to add items to cart')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenContext = context;
    var products = ref.watch(productProvider);
    return FloatingSideChat(
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('Shop'),
        ),
        drawer: AppDrawer(),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mediaQuery = MediaQuery.of(context);
              final width = constraints.maxWidth;
              final isLandscape =
                  mediaQuery.orientation == Orientation.landscape;

              int crossAxisCount = 1;
              if (width > 1200) {
                crossAxisCount = 4;
              } else if (width > 800) {
                crossAxisCount = 3;
              } else if (width > 500 || isLandscape) {
                crossAxisCount = 2;
              }

              return Container(
                color: Theme.of(context).colorScheme.surface,

                child: products.isEmpty
                    ? const Center(
                        child: Text(
                          'No products available',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(20),

                        itemCount: products.length,

                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,

                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,

                          childAspectRatio: width > 700 ? 0.60 : 0.50,
                        ),

                        itemBuilder: (itemContext, index) {
                          final prod = products[index];

                          return Material(
                            borderRadius: BorderRadius.circular(20),

                            elevation: 2,

                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),

                              onTap: () {
                                Navigator.push(
                                  screenContext,
                                  MaterialPageRoute(
                                    builder: (_) => Details(product: prod),
                                  ),
                                );
                              },

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  /// IMAGE
                                  Expanded(
                                    flex: 5,

                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),

                                      child: CachedNetworkImage(
                                        imageUrl: prod.imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        // Show a loading indicator while the image downloads
                                        placeholder: (context, url) =>
                                            const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                        // Handles broken URLs, missing images, or SSL errors
                                        errorWidget: (context, url, error) =>
                                            const Center(
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 48,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),

                                  /// CONTENT
                                  Expanded(
                                    flex: 5,

                                    child: Padding(
                                      padding: const EdgeInsets.all(14),

                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,

                                        children: [
                                          Flexible(
                                            child: Text(
                                              prod.title,

                                              maxLines: 2,

                                              overflow: TextOverflow.ellipsis,

                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),

                                          Flexible(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: ProductOfferPrice(
                                                    product: prod,
                                                    compact: true,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Stock: ${prod.stock}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: prod.stock > 0
                                                        ? Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant
                                                        : Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          LayoutBuilder(
                                            builder: (context, buttonConstraints) {
                                              final cardWidth =
                                                  buttonConstraints.maxWidth;
                                              final buttonStyle =
                                                  ElevatedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 4,
                                                        ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  );

                                              if (cardWidth < 220) {
                                                return Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    SizedBox(
                                                      height: 32,
                                                      child: ElevatedButton(
                                                        style: buttonStyle,
                                                        onPressed: () {
                                                          Navigator.push(
                                                            screenContext,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  Details(
                                                                    product:
                                                                        prod,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                        child: const Text(
                                                          "View",
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SizedBox(
                                                      height: 32,
                                                      child: ElevatedButton(
                                                        style: buttonStyle,
                                                        onPressed: () => ref
                                                            .read(
                                                              orderFlowProvider
                                                                  .notifier,
                                                            )
                                                            .placeProductOrder(
                                                              screenContext,
                                                              prod,
                                                            ),
                                                        child: const Text(
                                                          "Order",
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SizedBox(
                                                      height: 32,
                                                      child: ElevatedButton(
                                                        style: buttonStyle,
                                                        onPressed: () =>
                                                            _addToCart(
                                                              screenContext,
                                                              prod,
                                                            ),
                                                        child: const Text(
                                                          "Add",
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              } else {
                                                return Row(
                                                  children: [
                                                    Expanded(
                                                      child: SizedBox(
                                                        height: 32,
                                                        child: ElevatedButton(
                                                          style: buttonStyle,
                                                          onPressed: () {
                                                            Navigator.push(
                                                              screenContext,
                                                              MaterialPageRoute(
                                                                builder: (_) =>
                                                                    Details(
                                                                      product:
                                                                          prod,
                                                                    ),
                                                              ),
                                                            );
                                                          },
                                                          child: const Text(
                                                            "View",
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: SizedBox(
                                                        height: 32,
                                                        child: ElevatedButton(
                                                          style: buttonStyle,
                                                          onPressed: () => ref
                                                              .read(
                                                                orderFlowProvider
                                                                    .notifier,
                                                              )
                                                              .placeProductOrder(
                                                                screenContext,
                                                                prod,
                                                              ),
                                                          child: const Text(
                                                            "Order",
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: SizedBox(
                                                        height: 32,
                                                        child: ElevatedButton(
                                                          style: buttonStyle,
                                                          onPressed: () =>
                                                              _addToCart(
                                                                screenContext,
                                                                prod,
                                                              ),
                                                          child: const Text(
                                                            "Add",
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }
                                            },
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
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
