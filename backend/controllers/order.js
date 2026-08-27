const jwt = require('jsonwebtoken');
const Order = require('../models/order');
const Cart = require('../models/cart');
const { findProductById } = require('./product');
const stripe = require("stripe")(
  process.env.STRIPE_API_KEY
);

const SECRET_KEY = process.env.SECRET_KEY || 'your-secret-key-change-this';

// const getAuthenticatedUserId = (req) => {
//   const authHeader = req.headers.authorization || req.headers.Authorization;
//   if (!authHeader || !authHeader.startsWith('Bearer ')) return null;

//   try {
//     const token = authHeader.substring(7).trim();
//     const decoded = jwt.verify(token, SECRET_KEY);
//     return decoded.userId || decoded.id || null;
//   } catch (error) {
//     console.error('JWT verification failed:', error.message);
//     return null;
//   }
// };


const createPaymentIntent = async (req, res, next) => {
  try {
    const { amount } = req.body;

    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        error: 'A valid amount is required to create a payment intent.',
      });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: 'inr',
    });

    res.status(200).json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('Error creating payment intent:', error);
    res.status(500).json({ error: 'Failed to create payment intent' });
  }
};

const createCheckoutSession = async (req, res, next) => {
  try {
    const { amount } = req.body;

    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        error: 'A valid amount is required to create a checkout session.',
      });
    }

    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [{
        price_data: {
          currency: 'inr',
          product_data: { name: 'Store purchase' },
          unit_amount: amount,
        },
        quantity: 1,
      }],
      success_url: `${frontendUrl}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${frontendUrl}/payment-cancelled`,
    });

    return res.status(200).json({ url: session.url });
  } catch (error) {
    console.error('Error creating checkout session:', error);
    return res.status(500).json({ error: 'Failed to create checkout session' });
  }
};


const fetchOrders = async (req, res, next) => {
  try {
    const orders = await Order.find().sort({ orderedAt: -1 });

    return res.status(200).json({
      orders,
      message: orders.length === 0 ? 'Orders are empty' : 'Orders fetched successfully',
    });
  } catch (error) {
    console.error('Error fetching orders:', error);
    return res.status(500).json({
      message: 'Failed to fetch orders',
      error: error.message,
    });
  }
};

const placeOrder = async (req, res, next) => {
  try {
    const { productId, quantity, paymentIntentId } = req.body;
    const orderQty = Number(quantity);
    const userId = getAuthenticatedUserId(req);

    if (!userId) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    if (!productId || !Number.isFinite(orderQty) || orderQty < 1) {
      return res.status(400).json({
        message: 'productId and quantity (positive number) are required',
      });
    }

    // Require a paymentIntentId to verify payment before placing the order
    if (!paymentIntentId) {
      return res.status(400).json({ message: 'paymentIntentId is required' });
    }

    // Verify payment intent status with Stripe
    try {
      const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
      if (!pi || (pi.status !== 'succeeded' && pi.status !== 'requires_capture')) {
        return res.status(400).json({ message: 'Payment not completed' });
      }
    } catch (err) {
      console.error('Error retrieving payment intent:', err);
      return res.status(500).json({ message: 'Failed to verify payment intent' });
    }

    const product = await findProductById(productId);
    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    if (product.stock < orderQty) {
      return res.status(400).json({
        message: `Insufficient stock for ${product.title}. Only ${product.stock} items left.`,
      });
    }

    product.stock -= orderQty;
    await product.save();

    const newOrder = await Order.create({
      userId,
      productId: product._id.toString(),
      title: product.title,
      imageUrl: product.imageUrl || '',
      quantity: orderQty,
      price: product.price,
      orderedAt: new Date(),
    });

    // const productIdStr = String(productId);
    // const cartItem = await Cart.findOne({ prodId: productIdStr });
    // if (cartItem) {
    //   if (cartItem.quantity <= orderQty) {
    //     await Cart.deleteOne({ prodId: productIdStr });
    //   } else {
    //     cartItem.quantity -= orderQty;
    //     await cartItem.save();
    //   }
    // }

    // const cart = await Cart.find();

    return res.status(201).json({
      message: 'Order placed successfully',
      order: newOrder,
      // cart,
    });
  } catch (error) {
    console.error('Error placing order:', error);
    return res.status(500).json({
      message: 'Failed to place order',
      error: error.message,
    });
  }
};

const placeCartOrder = async (req, res, next) => {
  try {
    const { paymentIntentId } = req.body || {};
    const userId = getAuthenticatedUserId(req);

    if (!userId) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    if (!paymentIntentId) {
      return res.status(400).json({ message: 'paymentIntentId is required' });
    }

    // Verify payment intent
    try {
      const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
      if (!pi || (pi.status !== 'succeeded' && pi.status !== 'requires_capture')) {
        return res.status(400).json({ message: 'Payment not completed' });
      }
    } catch (err) {
      console.error('Error retrieving payment intent for cart order:', err);
      return res.status(500).json({ message: 'Failed to verify payment intent' });
    }

    const cartItems = await Cart.find();

    if (cartItems.length === 0) {
      return res.status(400).json({ message: 'Cart is empty' });
    }

    const resolved = [];
    for (const item of cartItems) {
      const product = await findProductById(item.prodId);
      if (!product) {
        return res.status(404).json({
          message: `Product not found for cart item: ${item.prodId}`,
        });
      }
      if (product.stock < item.quantity) {
        return res.status(400).json({
          message: `Insufficient stock for ${product.title}. Only ${product.stock} items left.`,
        });
      }
      resolved.push({ cartItem: item, product });
    }

    const createdOrders = [];
    const orderedAt = new Date();

    for (const { cartItem, product } of resolved) {
      product.stock -= cartItem.quantity;
      await product.save();

      const order = await Order.create({
        userId,
        productId: product._id.toString(),
        title: product.title,
        imageUrl: product.imageUrl || '',
        quantity: cartItem.quantity,
        price: product.price,
        orderedAt,
      });

      createdOrders.push(order);
    }

    await Cart.deleteMany({});

    return res.status(201).json({
      message: 'Cart ordered successfully',
      orders: createdOrders,
      cart: [],
    });
  } catch (error) {
    console.error('Error placing cart order:', error);
    return res.status(500).json({
      message: 'Failed to place cart order',
      error: error.message,
    });
  }
};


module.exports = {
  placeCartOrder,
  placeOrder,
  fetchOrders,
  createPaymentIntent,
  createCheckoutSession,
}

