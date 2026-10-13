import 'package:dummy_apps/model/product.dart';
import 'package:flutter/material.dart';

class ProductOfferPrice extends StatelessWidget {
  const ProductOfferPrice({
    super.key,
    required this.product,
    this.compact = false,
  });

  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPercentage > 0;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              '₹${product.discountedPrice.toStringAsFixed(2)}',
              style: (compact ? textTheme.titleSmall : textTheme.titleMedium)
                  ?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (hasDiscount)
              Text(
                '₹${product.price.toStringAsFixed(2)}',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            if (hasDiscount)
              Text(
                '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                style: textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        if (product.offerTitle.trim().isNotEmpty)
          Text(
            product.offerTitle.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
