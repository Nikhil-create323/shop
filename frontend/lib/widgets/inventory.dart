import 'package:dummy_apps/model/product.dart';

/// Local fallback catalog. The server catalog is authoritative for products
/// and stock; syncing this list must be an explicit development/bootstrap action.
final List<Product> inventory = [
  Product(
    id: 'inv-book-1',
    title: 'The Pragmatic Programmer',
    imageUrl:
        'https://images.unsplash.com/photo-1544947950-fa07a98df237?auto=format&fit=crop&w=600&q=80',
    price: 899,
  ),
  Product(
    id: 'inv-pen-1',
    title: 'Premium Gel Pen Pack (5)',
    imageUrl:
        'https://images.unsplash.com/photo-1585336267202-d4b0a0c4c28f?auto=format&fit=crop&w=600&q=80',
    price: 149,
  ),
  Product(
    id: 'inv-headphones-1',
    title: 'Wireless Noise-Cancelling Headphones',
    imageUrl:
        'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=600&q=80',
    price: 3499,
  ),
  Product(
    id: 'inv-watch-1',
    title: 'Minimalist Analog Watch',
    imageUrl:
        'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=600&q=80',
    price: 2199,
  ),
  Product(
    id: 'inv-keyboard-1',
    title: 'Mechanical Keyboard (RGB)',
    imageUrl:
        'https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=600&q=80',
    price: 4299,
  ),
  Product(
    id: 'inv-mug-1',
    title: 'Ceramic Coffee Mug',
    imageUrl:
        'https://images.unsplash.com/photo-1514228742587-6b1558fcca3d?auto=format&fit=crop&w=600&q=80',
    price: 399,
  ),
  Product(
    id: 'inv-backpack-1',
    title: 'Urban Travel Backpack',
    imageUrl:
        'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
    price: 1899,
  ),
  Product(
    id: 'inv-shoes-1',
    title: 'Running Shoes',
    imageUrl:
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=600&q=80',
    price: 2999,
  ),
  Product(
    id: 'inv-bottle-1',
    title: 'Insulated Steel Water Bottle',
    imageUrl:
        'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
    price: 699,
  ),
  Product(
    id: 'inv-lamp-1',
    title: 'LED Desk Lamp',
    imageUrl:
        'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=600&q=80',
    price: 1299,
  ),
  Product(
    id: 'inv-notebook-1',
    title: 'Ruled Spiral Notebook (A5)',
    imageUrl:
        'https://images.unsplash.com/photo-1531346680769-a1d79e2cbffc?auto=format&fit=crop&w=600&q=80',
    price: 199,
  ),
  Product(
    id: 'inv-mouse-1',
    title: 'Ergonomic Wireless Mouse',
    imageUrl:
        'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?auto=format&fit=crop&w=600&q=80',
    price: 999,
  ),
  Product(
    id: 'inv-plant-1',
    title: 'Desk Succulent Planter',
    imageUrl:
        'https://images.unsplash.com/photo-1485955900006-10f4d024d42c?auto=format&fit=crop&w=600&q=80',
    price: 449,
  ),
  Product(
    id: 'inv-sunglasses-1',
    title: 'Polarized Sunglasses',
    imageUrl:
        'https://images.unsplash.com/photo-1572635196233-224756081803?auto=format&fit=crop&w=600&q=80',
    price: 1599,
  ),
  Product(
    id: 'inv-speaker-1',
    title: 'Bluetooth Portable Speaker',
    imageUrl:
        'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=600&q=80',
    price: 2499,
  ),
  Product(
    id: 'inv-charger-1',
    title: 'USB-C Fast Charger 65W',
    imageUrl:
        'https://images.unsplash.com/photo-1591290619769-c37a3b00e04e?auto=format&fit=crop&w=600&q=80',
    price: 1199,
  ),
];
