const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const Order = require('../models/order');
const Cart = require('../models/cart');
const Product = require('../models/product');
const { findProductById } = require('./product');

const stripe = require("stripe")(
  process.env.STRIPE_API_KEY
);

const SECRET_KEY = process.env.SECRET_KEY || 'your-secret-key-change-this';

const getAuthenticatedUserId = (req) => {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;

  try {
    const token = authHeader.substring(7).trim();
    const decoded = jwt.verify(token, SECRET_KEY);
    return decoded.userId || decoded.id || null;
  } catch (error) {
    console.error('JWT verification failed:', error.message);
    return null;
  }
};

const getAuthenticatedRole = (req) => {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;

  try {
    const decoded = jwt.verify(authHeader.substring(7).trim(), SECRET_KEY);
    return decoded.role?.toString().toLowerCase() || null;
  } catch (error) {
    return null;
  }
};

const getVerifiedPaymentIntent = async (
  paymentIntentId,
  expectedAmount,
  userId,
  expectedCartSignature,
) => {
  if (!paymentIntentId) {
    return { error: 'paymentIntentId is required', status: 400 };
  }

  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
  if (!paymentIntent || paymentIntent.status !== 'succeeded') {
    return { error: 'Payment not completed', status: 400 };
  }

  if (paymentIntent.metadata?.userId !== String(userId)) {
    return { error: 'Payment does not belong to this account', status: 403 };
  }

  if (
    expectedCartSignature &&
    paymentIntent.metadata?.cartSignature !== expectedCartSignature
  ) {
    return { error: 'Cart contents changed after payment started', status: 409 };
  }

  if (paymentIntent.currency !== 'inr' ||
      paymentIntent.amount_received !== expectedAmount) {
    return { error: 'Paid amount does not match the current order total', status: 400 };
  }

  return { paymentIntent };
};

const refundUnfulfilledPaymentIntent = async (paymentIntentId, userId, idempotencyKey) => {
  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
  if (
    !paymentIntent ||
    paymentIntent.status !== 'succeeded' ||
    paymentIntent.metadata?.userId !== String(userId)
  ) {
    return false;
  }

  await stripe.refunds.create(
    { payment_intent: paymentIntentId },
    { idempotencyKey },
  );
  return true;
};

const reserveStock = async (product, quantity) => {
  const result = await Product.updateOne(
    { _id: product._id, stock: { $gte: quantity } },
    { $inc: { stock: -quantity } },
  );
  return result.matchedCount === 1;
};

const restoreStock = async (productId, quantity) => {
  const result = await Product.updateOne(
    { _id: productId },
    { $inc: { stock: quantity } },
  );
  return result.matchedCount === 1;
};

const orderError = (message, statusCode) => Object.assign(new Error(message), { statusCode });

const getFrontendReturnUrl = (checkoutStatus, fallbackUrl = null) => {
  const configuredUrl = process.env.FRONTEND_URL || fallbackUrl;
  if (!configuredUrl) return null;

  const frontendUrl = new URL(configuredUrl);
  if (
    !['http:', 'https:'].includes(frontendUrl.protocol) ||
    frontendUrl.username ||
    frontendUrl.password
  ) {
    throw new Error('FRONTEND_URL must be an absolute HTTP(S) URL without credentials');
  }
  frontendUrl.searchParams.set('checkout', checkoutStatus);
  return frontendUrl.toString();
};

const getCartSignature = (resolvedItems) => {
  const contents = resolvedItems
    .map(({ product, quantity }) =>
      `${product._id}:${quantity}:${getDiscountedUnitAmount(product)}`,
    )
    .sort()
    .join('|');
  return crypto.createHash('sha256').update(contents).digest('hex');
};

const getDiscountedUnitAmount = (product) => {
  const discountPercentage = Number(product.discountPercentage) || 0;
  return Math.round(product.price * (1 - discountPercentage / 100) * 100);
};

const createPaymentIntent = async (req, res, next) => {
  try {
    const { amount, cartCheckout, productId, quantity: requestedQuantity } = req.body;
    const userId = getAuthenticatedUserId(req);

    if (!userId) {
      return res.status(401).json({ message: 'Authentication required' });
    }
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(400).json({
        error: 'A valid amount is required to create a payment intent.',
      });
    }

    const metadata = { userId: String(userId) };
    if (cartCheckout === true) {
      const cartItems = await Cart.find({ userID: userId });
      if (cartItems.length === 0) {
        return res.status(400).json({ message: 'Cart is empty' });
      }

      const resolved = [];
      for (const item of cartItems) {
        const product = await findProductById(item.prodId);
        const quantity = Number(item.quantity);
        if (!product) {
          return res.status(404).json({ message: `Product not found for cart item: ${item.prodId}` });
        }
        if (!Number.isInteger(quantity) || quantity < 1 || product.stock < quantity) {
          return res.status(409).json({ message: `Insufficient or invalid stock for ${product.title}` });
        }
        resolved.push({ product, quantity });
      }

      const expectedAmount = resolved.reduce(
        (total, { product, quantity }) => total + getDiscountedUnitAmount(product) * quantity,
        0,
      );
      if (amount !== expectedAmount) {
        return res.status(400).json({ message: 'Cart total changed; refresh the cart and try again' });
      }
      metadata.cartSignature = getCartSignature(resolved);
    } else {
      const quantity = Number(requestedQuantity);
      if (!productId || !Number.isInteger(quantity) || quantity < 1) {
        return res.status(400).json({ message: 'productId and a positive integer quantity are required' });
      }
      const product = await findProductById(productId);
      if (!product) {
        return res.status(404).json({ message: 'Product not found' });
      }
      if (product.stock < quantity) {
        return res.status(409).json({ message: `Insufficient stock for ${product.title}` });
      }
      if (amount !== getDiscountedUnitAmount(product) * quantity) {
        return res.status(400).json({ message: 'Order total changed; refresh and try again' });
      }
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: 'inr',
      metadata,
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
    const { amount, cartCheckout, productId, quantity: requestedQuantity } = req.body;
    const userId = getAuthenticatedUserId(req);

    if (!userId) {
      return res.status(401).json({ message: 'Authentication required' });
    }
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(400).json({
        error: 'A valid amount is required to create a checkout session.',
      });
    }

    const lineItems = [];
    let expectedAmount = 0;
    let sessionMetadata;
    if (cartCheckout === true) {
      const cartItems = await Cart.find({ userID: userId });
      if (cartItems.length === 0) {
        return res.status(400).json({ message: 'Cart is empty' });
      }

      const resolved = [];
      for (const item of cartItems) {
        const product = await findProductById(item.prodId);
        const quantity = Number(item.quantity);
        if (!product) {
          return res.status(404).json({ message: `Product not found for cart item: ${item.prodId}` });
        }
        if (!Number.isInteger(quantity) || quantity < 1 || product.stock < quantity) {
          return res.status(409).json({ message: `Insufficient or invalid stock for ${product.title}` });
        }
        const unitAmount = getDiscountedUnitAmount(product);
        expectedAmount += unitAmount * quantity;
        resolved.push({ product, quantity });
        lineItems.push({
          price_data: {
            currency: 'inr',
            product_data: { name: product.title },
            unit_amount: unitAmount,
          },
          quantity,
        });
      }

      sessionMetadata = {
        userId: String(userId),
        checkoutType: 'cart',
        cartSignature: getCartSignature(resolved),
      };
    } else {
      const quantity = Number(requestedQuantity);
      if (!productId || !Number.isInteger(quantity) || quantity < 1) {
        return res.status(400).json({ message: 'productId and a positive integer quantity are required' });
      }
      const product = await findProductById(productId);
      if (!product) {
        return res.status(404).json({ message: 'Product not found' });
      }
      if (product.stock < quantity) {
        return res.status(409).json({ message: `Insufficient stock for ${product.title}` });
      }
      const unitAmount = getDiscountedUnitAmount(product);
      expectedAmount = unitAmount * quantity;
      lineItems.push({
        price_data: {
          currency: 'inr',
          product_data: { name: product.title },
          unit_amount: unitAmount,
        },
        quantity,
      });
      sessionMetadata = {
        userId: String(userId),
        checkoutType: 'single',
        productId: String(product._id),
        quantity: String(quantity),
      };
    }

    if (amount !== expectedAmount) {
      return res.status(400).json({ message: 'Order total changed; refresh and try again' });
    }

    const frontendUrl = process.env.FRONTEND_URL || req.get('origin') || null;
    getFrontendReturnUrl('success', frontendUrl);
    const frontendCancelUrl = getFrontendReturnUrl('cancelled', frontendUrl);
    if (!process.env.FRONTEND_URL && frontendUrl) {
      sessionMetadata.frontendOrigin = frontendUrl;
    }

    const configuredApiBaseUrl =
      process.env.API_BASE_URL || `${req.protocol}://${req.get('host')}`;
    const parsedApiBaseUrl = new URL(configuredApiBaseUrl);
    if (
      !['http:', 'https:'].includes(parsedApiBaseUrl.protocol) ||
      parsedApiBaseUrl.username ||
      parsedApiBaseUrl.password
    ) {
      throw new Error('API_BASE_URL must be an absolute HTTP(S) URL without credentials');
    }
    const apiBaseUrl = parsedApiBaseUrl.origin;
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: lineItems,
      client_reference_id: String(userId),
      metadata: sessionMetadata,
      payment_intent_data: {
        metadata: sessionMetadata,
      },
      success_url: `${apiBaseUrl}/api/checkout-success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: frontendCancelUrl || `${apiBaseUrl}/api/checkout-cancelled`,
    });

    return res.status(200).json({ url: session.url });
  } catch (error) {
    console.error('Error creating checkout session:', error);
    return res.status(500).json({ error: 'Failed to create checkout session' });
  }
};

const checkoutSuccess = async (req, res) => {
  const { session_id: sessionId } = req.query;
  if (typeof sessionId !== 'string' || !sessionId) {
    return res.status(400).send('Missing Checkout Session ID.');
  }

  try {
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    const userId = session.metadata?.userId;
    const paymentIntentId = typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id;

    if (
      session.payment_status !== 'paid' ||
      !userId ||
      session.client_reference_id !== userId ||
      !paymentIntentId
    ) {
      return res.status(400).send('Payment has not been confirmed.');
    }

    const frontendReturnUrl = getFrontendReturnUrl(
      'success',
      session.metadata?.frontendOrigin,
    );
    try {
      const checkoutType = session.metadata?.checkoutType;
      if (checkoutType === 'cart' && session.metadata?.cartSignature) {
        await fulfillCartOrder(userId, paymentIntentId);
      } else if (checkoutType === 'single') {
        await fulfillSingleOrder(
          userId,
          session.metadata?.productId,
          Number(session.metadata?.quantity),
          paymentIntentId,
        );
      } else {
        throw orderError('Checkout Session is missing order details', 400);
      }
      if (frontendReturnUrl) {
        return res.redirect(303, frontendReturnUrl);
      }
      return res.status(200).send(`
        <h1>Order confirmed</h1>
        <p>Your payment was successful and your order has been placed.</p>
        <p>You can return to the store.</p>
      `);
    } catch (error) {
      console.error('Hosted Checkout fulfillment failed:', error);
      try {
        const refunded = await refundUnfulfilledPaymentIntent(
          paymentIntentId,
          userId,
          `checkout-fulfillment-failed-${session.id}`,
        );
        if (!refunded) {
          return res.status(500).send(
            'Payment succeeded, but the order could not be placed or refunded automatically. Please contact support.',
          );
        }
      } catch (refundError) {
        console.error('Could not refund unfulfilled Checkout Session:', refundError);
        return res.status(500).send(
          'Payment succeeded, but order fulfillment and automatic refund failed. Please contact support.',
        );
      }
      return res.status(409).send(
        'The cart changed before the order could be placed. Your payment has been refunded.',
      );
    }
  } catch (error) {
    console.error('Checkout success handler failed:', error);
    return res.status(500).send('Unable to confirm this Checkout Session.');
  }
};

const checkoutCancelled = (req, res) => {
  try {
    const frontendReturnUrl = getFrontendReturnUrl('cancelled');
    if (frontendReturnUrl) {
      return res.redirect(303, frontendReturnUrl);
    }
  } catch (error) {
    console.error('Invalid Checkout return URL:', error);
    return res.status(500).send('Checkout return URL is not configured correctly.');
  }
  return res.status(200).send('<h1>Payment cancelled</h1><p>Your cart has not been changed.</p>');
};

const fetchOrders = async (req, res, next) => {
  try {
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({ message: 'Authentication required to fetch orders' });
    }

    const orders = await Order.find({ userId }).sort({ orderedAt: -1 });

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

const fulfillSingleOrder = async (userId, productId, quantity, paymentIntentId) => {
  let reserved = false;
  let reservedProductId;
  let createdOrderId;
  try {
    if (!productId || !Number.isInteger(quantity) || quantity < 1) {
      throw orderError('productId and a positive integer quantity are required', 400);
    }

    const existingOrder = await Order.findOne({ userId, paymentIntentId });
    if (existingOrder) return existingOrder;

    const product = await findProductById(productId);
    if (!product) throw orderError('Product not found', 404);

    const unitAmount = getDiscountedUnitAmount(product);
    const expectedAmount = unitAmount * quantity;
    const payment = await getVerifiedPaymentIntent(paymentIntentId, expectedAmount, userId);
    if (payment.error) throw orderError(payment.error, payment.status);

    if (!await reserveStock(product, quantity)) {
      const latestProduct = await Product.findById(product._id).lean();
      throw orderError(
        `Insufficient stock for ${product.title}. Only ${latestProduct?.stock ?? 0} left.`,
        409,
      );
    }
    reserved = true;
    reservedProductId = product._id;

    const order = await Order.create({
      userId,
      productId: product._id,
      title: product.title,
      imageUrl: product.imageUrl || '',
      quantity,
      price: unitAmount / 100,
      paymentIntentId,
      orderedAt: new Date(),
    });
    createdOrderId = order._id;
    return order;
  } catch (error) {
    if (createdOrderId) {
      try {
        await Order.deleteOne({ _id: createdOrderId });
      } catch (rollbackError) {
        console.error('Could not remove incomplete order:', rollbackError);
      }
    }
    if (reserved) {
      try {
        const restored = await restoreStock(reservedProductId, quantity);
        if (!restored) console.error(`Could not restore reserved stock for product ${productId}`);
      } catch (rollbackError) {
        console.error('Could not restore reserved stock:', rollbackError);
      }
    }
    throw error;
  }
};

const placeOrder = async (req, res) => {
  const userId = getAuthenticatedUserId(req);
  if (!userId) {
    return res.status(401).json({ message: 'Authentication required' });
  }
  const { productId, quantity, paymentIntentId } = req.body || {};
  if (!paymentIntentId) {
    return res.status(400).json({ message: 'paymentIntentId is required' });
  }

  try {
    const order = await fulfillSingleOrder(
      userId,
      productId,
      Number(quantity),
      paymentIntentId,
    );
    return res.status(201).json({ message: 'Order placed successfully', order });
  } catch (error) {
    console.error('Error placing order:', error);
    let refunded = false;
    try {
      refunded = await refundUnfulfilledPaymentIntent(
        paymentIntentId,
        userId,
        `order-fulfillment-failed-${paymentIntentId}`,
      );
    } catch (refundError) {
      console.error('Could not refund failed order fulfillment:', refundError);
    }
    return res.status(error.statusCode || 500).json({
      message: refunded
        ? `Order could not be placed. Payment refunded: ${error.message}`
        : error.statusCode ? error.message : 'Failed to place order',
      error: error.message,
    });
  }
};

const fulfillCartOrder = async (userId, paymentIntentId) => {
  const reservedProducts = [];
  const createdOrderIds = [];
  try {
    const existingOrders = await Order.find({ userId, paymentIntentId });
    if (existingOrders.length > 0) {
      return {
        orders: existingOrders,
        cart: await Cart.find({ userID: userId }),
        alreadyPlaced: true,
      };
    }

    const cartItems = await Cart.find({ userID: userId });

    if (cartItems.length === 0) {
      throw orderError('Cart is empty', 400);
    }

    const resolved = [];
    for (const item of cartItems) {
      const product = await findProductById(item.prodId);
      if (!product) {
        throw orderError(`Product not found for cart item: ${item.prodId}`, 404);
      }
      const quantity = Number(item.quantity);
      if (!Number.isInteger(quantity) || quantity < 1) {
        throw orderError(`Invalid quantity for ${product.title}`, 400);
      }
      if (product.stock < quantity) {
        throw orderError(
          `Insufficient stock for ${product.title}. Only ${product.stock} items left.`,
          409,
        );
      }
      resolved.push({ cartItem: item, product, quantity });
    }

    const expectedAmount = resolved.reduce(
      (total, { product, quantity }) =>
        total + getDiscountedUnitAmount(product) * quantity,
      0,
    );
    let payment;
    try {
      payment = await getVerifiedPaymentIntent(
        paymentIntentId,
        expectedAmount,
        userId,
        getCartSignature(resolved),
      );
    } catch (error) {
      console.error('Error verifying payment intent for cart order:', error);
      throw orderError('Failed to verify payment intent', 500);
    }
    if (payment.error) {
      throw orderError(payment.error, payment.status);
    }

    const createdOrders = [];
    const orderedAt = new Date();

    for (const { product, quantity } of resolved) {
      if (!await reserveStock(product, quantity)) {
        const latestProduct = await Product.findById(product._id).lean();
        const available = latestProduct?.stock ?? 0;
        throw orderError(
          `Insufficient stock for ${product.title}. Only ${available} items left.`,
          409,
        );
      }
      reservedProducts.push({ productId: product._id, quantity });

      const order = await Order.create({
        userId,
        productId: product._id.toString(),
        title: product.title,
        imageUrl: product.imageUrl || '',
        quantity,
        price: getDiscountedUnitAmount(product) / 100,
        paymentIntentId,
        orderedAt,
      });

      createdOrders.push(order);
      createdOrderIds.push(order._id);
    }

    await Cart.deleteMany({ userID: userId });

    return {
      orders: createdOrders,
      cart: [],
      alreadyPlaced: false,
    };
  } catch (error) {
    if (createdOrderIds.length > 0) {
      try {
        await Order.deleteMany({ _id: { $in: createdOrderIds } });
      } catch (rollbackError) {
        console.error('Could not remove incomplete cart orders:', rollbackError);
      }
    }
    for (const { productId, quantity } of reservedProducts) {
      try {
        const restored = await restoreStock(productId, quantity);
        if (!restored) {
          console.error(`Could not restore reserved stock for product ${productId}`);
        }
      } catch (rollbackError) {
        console.error(`Could not restore reserved stock for product ${productId}:`, rollbackError);
      }
    }
    throw error;
  }
};

const placeCartOrder = async (req, res) => {
  const userId = getAuthenticatedUserId(req);
  if (!userId) {
    return res.status(401).json({ message: 'Authentication required' });
  }

  const { paymentIntentId } = req.body || {};
  if (!paymentIntentId) {
    return res.status(400).json({ message: 'paymentIntentId is required' });
  }

  try {
    const result = await fulfillCartOrder(userId, paymentIntentId);
    return res.status(201).json({
      message: result.alreadyPlaced ? 'Cart order was already placed' : 'Cart ordered successfully',
      orders: result.orders,
      cart: result.cart,
    });
  } catch (error) {
    console.error('Error placing cart order:', error);
    let refunded = false;
    try {
      refunded = await refundUnfulfilledPaymentIntent(
        paymentIntentId,
        userId,
        `cart-fulfillment-failed-${paymentIntentId}`,
      );
    } catch (refundError) {
      console.error('Could not refund failed cart fulfillment:', refundError);
    }
    return res.status(error.statusCode || 500).json({
      message: refunded
        ? `Cart order could not be placed. Payment refunded: ${error.message}`
        : error.statusCode ? error.message : 'Failed to place cart order',
      error: error.message,
    });
  }
};

const cancelOrder = async (req, res) => {
  const userId = getAuthenticatedUserId(req);
  if (!userId) {
    return res.status(401).json({ message: 'Authentication required' });
  }

  try {
    const order = await Order.findOne({ _id: req.params.orderId, userId });
    if (!order) return res.status(404).json({ message: 'Order not found' });
    if (order.status !== 'placed') {
      return res.status(400).json({ message: 'Only placed orders can be cancelled' });
    }
    if (!order.paymentIntentId) {
      return res.status(400).json({ message: 'This order cannot be refunded automatically' });
    }

    const product = await Product.findById(order.productId);
    if (!product) {
      return res.status(404).json({ message: 'Product no longer exists; cancellation needs support' });
    }

    const claimedOrder = await Order.findOneAndUpdate(
      { _id: order._id, status: 'placed' },
      { $set: { status: 'cancelling' } },
      { new: true },
    );
    if (!claimedOrder) {
      return res.status(409).json({ message: 'Order is already being updated' });
    }

    let refund;
    try {
      refund = await stripe.refunds.create(
        {
          payment_intent: order.paymentIntentId,
          amount: Math.round(order.price * 100) * order.quantity,
        },
        { idempotencyKey: `order-cancel-${order._id}` },
      );
    } catch (error) {
      await Order.updateOne({ _id: order._id, status: 'cancelling' }, { $set: { status: 'placed' } });
      console.error('Order cancellation refund failed:', error);
      return res.status(502).json({ message: 'Refund failed; the order remains active' });
    }

    const restored = await restoreStock(product._id, order.quantity);
    if (!restored) {
      await Order.updateOne(
        { _id: order._id, status: 'cancelling' },
        { $set: { status: 'cancelled', refundId: refund.id } },
      );
      return res.status(500).json({ message: 'Refund succeeded but inventory could not be restored' });
    }

    const updatedOrder = await Order.findOneAndUpdate(
      { _id: order._id, status: 'cancelling' },
      { $set: { status: 'cancelled', refundId: refund.id } },
      { new: true },
    );
    return res.status(200).json({ message: 'Order cancelled and refunded', order: updatedOrder });
  } catch (error) {
    console.error('Order cancellation failed:', error);
    return res.status(500).json({ message: 'Failed to cancel order', error: error.message });
  }
};

const requestReturn = async (req, res) => {
  const userId = getAuthenticatedUserId(req);
  if (!userId) {
    return res.status(401).json({ message: 'Authentication required' });
  }

  try {
    const order = await Order.findOneAndUpdate(
      { _id: req.params.orderId, userId, status: { $in: ['placed', 'return_rejected'] } },
      { $set: { status: 'return_requested' } },
      { new: true },
    );
    if (!order) {
      return res.status(404).json({ message: 'Order not found or is not eligible for return' });
    }
    return res.status(200).json({ message: 'Return requested', order });
  } catch (error) {
    console.error('Return request failed:', error);
    return res.status(500).json({ message: 'Failed to request return', error: error.message });
  }
};

const fetchReturnRequests = async (req, res) => {
  if (getAuthenticatedRole(req) !== 'admin') {
    return res.status(403).json({ message: 'Admin authentication required' });
  }

  try {
    const orders = await Order.find({ status: 'return_requested' }).sort({ orderedAt: -1 });
    return res.status(200).json({ orders });
  } catch (error) {
    console.error('Failed to fetch return requests:', error);
    return res.status(500).json({ message: 'Failed to fetch return requests', error: error.message });
  }
};

const processReturnRequest = async (req, res) => {
  if (getAuthenticatedRole(req) !== 'admin') {
    return res.status(403).json({ message: 'Admin authentication required' });
  }

  const decision = req.body?.decision;
  if (!['approve', 'reject'].includes(decision)) {
    return res.status(400).json({ message: 'decision must be approve or reject' });
  }

  try {
    if (decision === 'reject') {
      const order = await Order.findOneAndUpdate(
        { _id: req.params.orderId, status: 'return_requested' },
        { $set: { status: 'return_rejected' } },
        { new: true },
      );
      if (!order) return res.status(404).json({ message: 'Return request not found' });
      return res.status(200).json({ message: 'Return request rejected', order });
    }

    const order = await Order.findOneAndUpdate(
      { _id: req.params.orderId, status: 'return_requested' },
      { $set: { status: 'return_processing' } },
      { new: true },
    );
    if (!order) return res.status(404).json({ message: 'Return request not found' });
    if (!order.paymentIntentId) {
      await Order.updateOne({ _id: order._id, status: 'return_processing' }, { $set: { status: 'return_requested' } });
      return res.status(400).json({ message: 'This order cannot be refunded automatically' });
    }

    const product = await Product.findById(order.productId);
    if (!product) {
      await Order.updateOne({ _id: order._id, status: 'return_processing' }, { $set: { status: 'return_requested' } });
      return res.status(404).json({ message: 'Product no longer exists; return needs support' });
    }

    let refund;
    try {
      refund = await stripe.refunds.create(
        {
          payment_intent: order.paymentIntentId,
          amount: Math.round(order.price * 100) * order.quantity,
        },
        { idempotencyKey: `order-return-${order._id}` },
      );
    } catch (error) {
      await Order.updateOne({ _id: order._id, status: 'return_processing' }, { $set: { status: 'return_requested' } });
      console.error('Return refund failed:', error);
      return res.status(502).json({ message: 'Refund failed; the return remains pending' });
    }

    const restored = await restoreStock(product._id, order.quantity);
    if (!restored) {
      await Order.updateOne(
        { _id: order._id, status: 'return_processing' },
        { $set: { status: 'returned', refundId: refund.id } },
      );
      return res.status(500).json({ message: 'Refund succeeded but inventory could not be restored' });
    }

    const updatedOrder = await Order.findOneAndUpdate(
      { _id: order._id, status: 'return_processing' },
      { $set: { status: 'returned', refundId: refund.id } },
      { new: true },
    );
    return res.status(200).json({ message: 'Return approved, refunded, and restocked', order: updatedOrder });
  } catch (error) {
    console.error('Failed to process return request:', error);
    return res.status(500).json({ message: 'Failed to process return request', error: error.message });
  }
};

module.exports = {
  placeCartOrder,
  placeOrder,
  fetchOrders,
  createPaymentIntent,
  createCheckoutSession,
  checkoutSuccess,
  checkoutCancelled,
  cancelOrder,
  requestReturn,
  fetchReturnRequests,
  processReturnRequest,
}
