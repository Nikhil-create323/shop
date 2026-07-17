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

module.exports = {
  fetchProducts,
  seedProducts,
  findProductById,
};
