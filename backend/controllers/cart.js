const jwt = require('jsonwebtoken');
const Product = require('../models/product');
const Cart = require('../models/cart');

const SECRET_KEY = process.env.SECRET_KEY || 'your-secret-key-change-this';

const getAuthenticatedUserId = (req) => {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;

  try {
    const token = authHeader.substring(7).trim();
    const decoded = jwt.verify(token, SECRET_KEY);
    return decoded.userId || decoded.id || null;
  } catch (error) {
    return null;
  }
};

const addToCart = async (req, res) => {
  try {
    const { prodId } = req.body;
    const userId = getAuthenticatedUserId(req);

    if (!userId) {
      return res.status(401).json({ message: 'Authentication required to add to cart' });
    }
    
    const prodIdStr = prodId != null ? String(prodId) : '';

    if (!prodIdStr) {
      return res.status(400).json({
        message: 'No product received',
      });
    }

    const existing = await Cart.findOne({ prodId: prodIdStr, userID: userId });

    if (existing) {
      existing.quantity += 1;
      await existing.save();
    } else {
      await Cart.create({
        userID: userId,
        prodId: prodIdStr,
        quantity: 1,
        user: userId,
      });
    }

    const fullCartList = await Cart.find({ userID: userId });

    res.status(200).json({
      message: 'Cart updated successfully',
      data: fullCartList,
    });

  } catch (error) {
    res.status(500).json({
      message: "Error saving product",
      error: error.message
    });
  }
};

const fetchCart = async (req, res) => {
  try {
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(200).json({
        message: 'Cart fetched successfully',
        data: [],
      });
    }

    const cart = await Cart.find({ userID: userId });

    return res.status(200).json({
      message: 'Cart fetched successfully',
      data: cart,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Something went wrong',
      error: error.message,
    });
  }
};

const removeFromCart = async (req, res) => {
  try {
    const { prodId, removeAll } = req.body;
    const userId = getAuthenticatedUserId(req);

    if (!userId) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    const prodIdStr = prodId != null ? String(prodId) : '';

    if (!prodIdStr) {
      return res.status(400).json({
        message: 'No product ID received',
      });
    }

    const cartItem = await Cart.findOne({ prodId: prodIdStr, userID: userId });

    if (!cartItem) {
      return res.status(404).json({
        message: 'Product not found in cart',
      });
    }

    if (removeAll === true || removeAll === 'true') {
      await Cart.deleteOne({ prodId: prodIdStr, userID: userId });
    } else if (cartItem.quantity > 1) {
      cartItem.quantity -= 1;
      await cartItem.save();
    } else {
      await Cart.deleteOne({ prodId: prodIdStr, userID: userId });
    }

    const fullCartList = await Cart.find({ userID: userId });

    return res.status(200).json({
      message: 'Product removed from cart successfully',
      data: fullCartList,
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Error removing product from cart',
      error: error.message,
    });
  }
};


const clearCart = async (req, res) => {
  try {
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    await Cart.deleteMany({ userID: userId });
    return res.status(200).json({
      message: 'Cart cleared successfully',
    });

  } catch (err) {
    return res.status(500).json({
      message: 'Error clearing cart',
      error: err.message,
    });
  }
}

module.exports = {addToCart, fetchCart, removeFromCart, clearCart};