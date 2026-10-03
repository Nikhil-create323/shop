const mongoose = require('mongoose');
const Product = require('../models/product');
const { seedCatalogToDb } = require('../utils/seedProducts');

async function fetchProducts(req, res, next) {
  try {
    const products = await Product.find().sort({ title: 1 }).lean();
    return res.status(200).json({
      products,
      message: products.length === 0 ? 'Products are empty' : 'Products fetched successfully',
    });
  } catch (error) {
    console.error('fetchProducts error:', error);
    return res.status(500).json({ message: 'Failed to fetch products', error: error.message });
  }
}

async function seedProducts(req, res, next) {
  try {
    // Accept items as body array or { items: [...] }
    const items = Array.isArray(req.body)
      ? req.body
      : Array.isArray(req.body?.items)
      ? req.body.items
      : Array.isArray(req.body?.products)
      ? req.body.products
      : [];

    if (!items || items.length === 0) {
      return res.status(400).json({ message: 'No product items provided to seed' });
    }

    const { count, products } = await seedCatalogToDb(items);

    return res.status(200).json({ message: 'Seed completed', count, products });
  } catch (error) {
    console.error('seedProducts error:', error);
    return res.status(500).json({ message: 'Failed to seed products', error: error.message });
  }
}

async function findProductById(input) {
  const normalizedId =
    input && typeof input === 'object' && !Array.isArray(input)
      ? input.productId ?? input.id ?? input._id ?? input.value ?? input
      : input;

  if (!normalizedId) return null;

  const rawId = String(normalizedId).trim();
  if (!rawId) return null;

  try {
    if (mongoose.Types.ObjectId.isValid(rawId)) {
      const p = await Product.findById(rawId);
      if (p) return p;
    }

    return await Product.findOne({ $or: [{ sku: rawId }, { _id: rawId }] });
  } catch (err) {
    console.error('findProductById error:', err);
    return null;
  }
}

async function createProduct(req, res) {
  try {
    const { title, price, costPrice, stock, imageUrl, discountPercentage, offerTitle } = req.body;
    if (!title || price === undefined) {
      return res.status(400).json({ message: 'Title and price are required' });
    }

    const product = await Product.create({
      title,
      price: Number(price),
      costPrice: costPrice !== undefined ? Number(costPrice) : 0,
      stock: stock !== undefined ? Number(stock) : 10,
      imageUrl: imageUrl || 'https://via.placeholder.com/150',
      discountPercentage: discountPercentage !== undefined ? Number(discountPercentage) : 0,
      offerTitle: offerTitle || '',
    });

    return res.status(201).json({ message: 'Product created successfully', product });
  } catch (error) {
    console.error('createProduct error:', error);
    return res.status(500).json({ message: 'Failed to create product', error: error.message });
  }
}

async function updateProduct(req, res) {
  try {
    const { id } = req.params;
    const { title, price, costPrice, stock, imageUrl, discountPercentage, offerTitle } = req.body;

    const product = await findProductById(id);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    if (title !== undefined) product.title = title;
    if (price !== undefined) product.price = Number(price);
    if (costPrice !== undefined) product.costPrice = Number(costPrice);
    if (stock !== undefined) product.stock = Number(stock);
    if (imageUrl !== undefined) product.imageUrl = imageUrl;
    if (discountPercentage !== undefined) product.discountPercentage = Number(discountPercentage);
    if (offerTitle !== undefined) product.offerTitle = offerTitle;

    await product.save();
    return res.status(200).json({ message: 'Product updated successfully', product });
  } catch (error) {
    console.error('updateProduct error:', error);
    return res.status(500).json({ message: 'Failed to update product', error: error.message });
  }
}

async function deleteProduct(req, res) {
  try {
    const { id } = req.params;
    const product = await findProductById(id);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    await Product.deleteOne({ _id: product._id });
    return res.status(200).json({ message: 'Product deleted successfully', id });
  } catch (error) {
    console.error('deleteProduct error:', error);
    return res.status(500).json({ message: 'Failed to delete product', error: error.message });
  }
}

async function getAdminDashboardStats(req, res) {
  try {
    const Order = require('../models/order');
    const products = await Product.find().lean();
    const orders = await Order.find().lean();

    // Map sales by productId or title
    const salesMap = {}; // { idStr: { title, quantity: 0, revenue: 0, cost: 0, imageUrl } }
    products.forEach((p) => {
      salesMap[p._id.toString()] = {
        id: p._id.toString(),
        title: p.title,
        quantity: 0,
        revenue: 0,
        costPrice: p.costPrice || 0,
        imageUrl: p.imageUrl,
      };
    });

    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    let dailyRevenue = 0;
    let dailyCost = 0;
    let dailyOrderCount = 0;

    let monthlyRevenue = 0;
    let monthlyCost = 0;
    let monthlyOrderCount = 0;
    const excludedStatuses = new Set(['cancelled', 'returned']);

    orders.forEach((order) => {
      if (excludedStatuses.has(order.status)) return;

      const pId = order.productId ? order.productId.toString() : null;
      const qty = order.quantity || 1;
      const rev = (order.price || 0) * qty;

      // Match product cost price if available
      const matchedProduct = products.find((p) => p._id.toString() === pId || p.title === order.title);
      const unitCost = matchedProduct ? matchedProduct.costPrice || 0 : 0;
      const totalCost = unitCost * qty;

      if (salesMap[pId]) {
        salesMap[pId].quantity += qty;
        salesMap[pId].revenue += rev;
      } else {
        salesMap[order.title] = salesMap[order.title] || {
          id: pId || order.title,
          title: order.title,
          quantity: 0,
          revenue: 0,
          costPrice: unitCost,
          imageUrl: order.imageUrl || '',
        };
        salesMap[order.title].quantity += qty;
        salesMap[order.title].revenue += rev;
      }

      const orderDate = new Date(order.orderedAt || order.createdAt || Date.now());
      if (orderDate >= startOfToday) {
        dailyRevenue += rev;
        dailyCost += totalCost;
        dailyOrderCount += 1;
      }
      if (orderDate >= startOfMonth) {
        monthlyRevenue += rev;
        monthlyCost += totalCost;
        monthlyOrderCount += 1;
      }
    });

    const salesList = Object.values(salesMap);
    salesList.sort((a, b) => b.quantity - a.quantity);

    const mostSold = salesList.length > 0 ? salesList[0] : null;
    const leastSold = salesList.length > 0 ? salesList[salesList.length - 1] : null;

    return res.status(200).json({
      mostSold,
      leastSold,
      dailyStats: {
        revenue: dailyRevenue,
        cost: dailyCost,
        profit: dailyRevenue - dailyCost,
        ordersCount: dailyOrderCount,
      },
      monthlyStats: {
        revenue: monthlyRevenue,
        cost: monthlyCost,
        profit: monthlyRevenue - monthlyCost,
        ordersCount: monthlyOrderCount,
      },
      totalProducts: products.length,
      totalStockUnits: products.reduce((total, product) => total + (product.stock || 0), 0),
      totalOrders: orders.length,
    });
  } catch (error) {
    console.error('getAdminDashboardStats error:', error);
    return res.status(500).json({ message: 'Failed to fetch dashboard stats', error: error.message });
  }
}

module.exports = {
  fetchProducts,
  seedProducts,
  findProductById,
  createProduct,
  updateProduct,
  deleteProduct,
  getAdminDashboardStats,
};
