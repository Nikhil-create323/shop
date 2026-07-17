const Product = require('../models/product')
const Cart = require('../models/cart');

const addToCart = async (req, res) => {
  try {
    const { prodId } = req.body;
    const user = req.body.user;
    
    const prodIdStr = prodId != null ? String(prodId) : '';

    if (!prodIdStr) {
      return res.status(400).json({
        message: 'No product received',
      });
    }

    const existing = await Cart.findOne({ prodId: prodIdStr });

    if (existing) {
      existing.quantity += 1;
      await existing.save();
    } else {
      await Cart.create({
        prodId: prodIdStr,
        quantity: 1,
      });
    }

    const fullCartList = await Cart.find();

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
    const cart = await Cart.find();

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
    const prodIdStr = prodId != null ? String(prodId) : '';

    if (!prodIdStr) {
      return res.status(400).json({
        message: 'No product ID received',
      });
    }

    const cartItem = await Cart.findOne({ prodId: prodIdStr });

    if (!cartItem) {
      return res.status(404).json({
        message: 'Product not found in cart',
      });
    }

    if (removeAll === true || removeAll === 'true') {
      await Cart.deleteOne({ prodId: prodIdStr });
    } else if (cartItem.quantity > 1) {
      cartItem.quantity -= 1;
      await cartItem.save();
    } else {
      await Cart.deleteOne({ prodId: prodIdStr });
    }

    const fullCartList = await Cart.find();

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
    const cartItems =await Cart.deleteMany({ user: req.user.id });
    if(cart.deletedCount > 0) {
      return res.status(200).json({
        message: 'Cart cleared successfully',
      });

    } else {
      return res.status(404).json({
        message: 'No items found in the cart to clear',
      });
    }

  } catch (err) {
    return res.status(500).json({
      message: 'Error clearing cart',
      error: err.message,
    });
  }
}

module.exports = {addToCart, fetchCart, removeFromCart};