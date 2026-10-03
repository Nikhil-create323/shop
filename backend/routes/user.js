const express = require('express');
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const router = express.Router();
const cart = require('../controllers/cart')

const userController = require('../controllers/user');
const productController = require('../controllers/product');
const assistantController = require('../controllers/assistant');
const ratingController = require('../controllers/rating');
const orderController = require('../controllers/order');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 8,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many authentication attempts, please wait and try again later.' },
});

const assistantLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many assistant requests. Please wait a minute and try again.' },
});


// Define your route on the 'router' object
router.post(
  '/login',
  authLimiter,
  [
    body('email').isEmail().withMessage('Valid email is required'),
    body('password')
      .isString()
      .isLength({ min: 6, max: 128 })
      .withMessage('Password must be 6-128 characters'),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return userController.logIn(req, res, next);
  },
);

router.post(
  '/signup',
  authLimiter,
  [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('email').isEmail().withMessage('Valid email is required'),
    body('password')
      .isString()
      .isLength({ min: 6, max: 128 })
      .withMessage('Password must be 6-128 characters'),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    return userController.signUp(req, res, next);
  },
);
// router.get("/oauth2callback", async (req, res) => {
//   const code = req.query.code;

//   const response = await fetch("https://oauth2.googleapis.com/token", {
//     method: "POST",
//     headers: {
//       "Content-Type": "application/x-www-form-urlencoded",
//     },
//     body: new URLSearchParams({
//       client_id: process.env.GOOGLE_CLIENT_ID,
//       client_secret: process.env.GOOGLE_CLIENT_SECRET,
//       code: "4/0AdkVLPxiB399qiy92YoA1jqZ31XLcVfUvuhjAqnCEnI3EwF0dD9tnZjZh4k8b3_XD0pKJw&scope",
//       grant_type: "authorization_code",
//       redirect_uri: "http://localhost:3000/oauth2callback",
//     }),
//   });

//   const tokens = await response.json();

//   console.log(tokens);
//   res.send(tokens);
// });

router.post('/api/google-auth', authLimiter, userController.googleAuth);
router.post('/forgot-password', authLimiter, userController.forgotPassword);
router.post('/reset-password', authLimiter, userController.resetPassword);
// router.post('/change-password', userController.changePassword);



router.post('/addRating/:productId', ratingController.addRating);
router.get('/api/rating/:productId', ratingController.fetchRatings);
router.post('/api/rating/:ratingId/upvote', ratingController.upvote);
router.post('/api/rating/:ratingId/downvote', ratingController.downvote);
router.get('/api/fetchSummary/:productId', ratingController.fetchSummaryFromN8N);
router.post('/api/assistant', assistantLimiter, assistantController.searchFilter);
router.post('/api/create-payment-intent', orderController.createPaymentIntent);
router.post('/api/create-checkout-session', orderController.createCheckoutSession);
router.get('/api/checkout-success', orderController.checkoutSuccess);
router.get('/api/checkout-cancelled', orderController.checkoutCancelled);

router.get('/fetchCart', cart.fetchCart);
router.get('/fetchRatings/:productId', ratingController.fetchRatings);



router.get('/fetchOrders', orderController.fetchOrders);

router.post('/placeOrder', orderController.placeOrder);
router.post('/placeCartOrder', orderController.placeCartOrder);
router.post('/cancelOrder/:orderId', orderController.cancelOrder);
router.post('/requestReturn/:orderId', orderController.requestReturn);


router.post('/addToCart', cart.addToCart);
router.post('/removeFromCart', cart.removeFromCart);
// router.post('/clearCart', cart.clearCart);

router.get('/fetchProducts', productController.fetchProducts);
router.post('/seedProducts', productController.seedProducts);

// Admin Routes
router.post('/api/admin/products', productController.createProduct);
router.put('/api/admin/products/:id', productController.updateProduct);
router.delete('/api/admin/products/:id', productController.deleteProduct);
router.get('/api/admin/dashboard', productController.getAdminDashboardStats);
router.get('/api/admin/return-requests', orderController.fetchReturnRequests);
router.post('/api/admin/return-requests/:orderId', orderController.processReturnRequest);

// router.get('/email', userController.authUrl);
module.exports = router;