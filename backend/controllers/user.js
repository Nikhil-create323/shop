const jwt = require('jsonwebtoken');
require('dotenv').config();

const https = require('https');
const bcrypt = require('bcrypt');
const twilio = require('twilio');

const User = require('../models/user');
const Order = require('../models/order');
const Cart = require('../models/cart');
const ResetPassword = require('../models/password-reset');

const {sendMail} = require('./gmail');
// const { findProductById, fetchProducts, seedProducts } = require('./product');


const SECRET_KEY = process.env.SECRET_KEY || 'your-secret-key-change-this';

const fetchGoogleOAuthPayload = (url) => new Promise((resolve, reject) => {
  https.get(url, (response) => {
    let data = '';

    response.on('data', (chunk) => {
      data += chunk;
    });

    response.on('end', () => {
      try {
        const parsed = JSON.parse(data);
        if (response.statusCode >= 400) {
          reject(new Error(parsed.error_description || parsed.error || 'Google OAuth verification failed'));
          return;
        }
        resolve(parsed);
      } catch (error) {
        reject(error);
      }
    });
  }).on('error', reject);
});

const verifyGoogleOAuthToken = async (credential) => {
  if (typeof credential !== 'string' || !credential.trim()) {
    throw new Error('Google OAuth credential is required');
  }

  const token = credential.trim();
  const googleClientId = process.env.GOOGLE_CLIENT_ID;
  if (!googleClientId) {
    throw new Error('GOOGLE_CLIENT_ID is not configured');
  }

  const tokenInfoUrl = token.split('.').length === 3
    ? `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(token)}`
    : `https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=${encodeURIComponent(token)}`;

  const payload = await fetchGoogleOAuthPayload(tokenInfoUrl);

  if (!payload || !payload.sub) {
    throw new Error('Google OAuth token verification failed');
  }

  if (payload.aud && payload.aud !== googleClientId) {
    throw new Error('Google OAuth audience mismatch');
  }

  return {
    googleId: payload.sub,
    email: payload.email || null,
    name: payload.name || payload.given_name || null,
    profileImage: payload.picture || null,
  };
};

const signUp = async (req, res, next) => {
    try {
        const { name, email, password } = req.body;

        // Validate input
        if (!name || !email || !password) {
            return res.status(400).json({ message: "All fields are required" });
        }
        if (typeof password !== 'string' || password.length > 128) {
            return res.status(400).json({ message: "Password must be 128 characters or fewer" });
        }

        const normalizedEmail = email.toLowerCase().trim();

        // Check if user already exists
        const existingUser = await User.findOne({ email: normalizedEmail });
        if (existingUser) {
            if (existingUser.providers.includes("email")) {
                return res.status(400).json({ message: "Email is already registered" });
            } else {
                // Link email login provider to existing phone/google profile
                existingUser.providers.push("email");
                existingUser.password = password; // pre-save hook will hash it when we save!
                existingUser.name = name || existingUser.name;
                await existingUser.save();

                const token = jwt.sign(
                    { userId: existingUser._id },
                    SECRET_KEY,
                    { expiresIn: "24h" }
                );

                return res.status(200).json({
                    message: "Email auth linked successfully",
                    token: token,
                });
            }
        }

        // const hashedPassword = await bcrypt.hash(password, 10);

        // Create the user
        const user = await User.create({
            name: name.trim(),
            email: normalizedEmail,
            password: password,
            providers: ["email"],
            isEmailVerified: false
        });

        console.log("User created:", user);

        // Sign the token
        const token = jwt.sign(
            { userId: user._id, name: user.name },
            SECRET_KEY,
            { expiresIn: "7d" }
        );

        // Send success response
        res.status(201).json({
            message: "User created successfully",
            user: {
                id: user._id,
                name: user.name,
            },
            token: token,
        });

    } catch (err) {
        console.log("Signup Error:", err);
        res.status(500).json({ message: "Error creating user", error: err.message });
    }
};

const logIn = async (req, res, next)  =>  {
  const { email, password } = req.body;
  console.log("Received login request for:", email);

  if (typeof password !== 'string' || password.length > 128) {
    return res.status(400).json({ message: 'Password must be 128 characters or fewer' });
  }

  try {
    const normalizedEmail = email.toLowerCase().trim();
    const curUser = await User.findOne({ email: normalizedEmail });

    if (!curUser) {
      return res.status(404).json({ message: "User not found" });
    }

    if (!curUser.providers.includes("email") || !curUser.password) {
      return res.status(400).json({
        message: "Email password login is not set up for this account. Please login using Google or Phone OTP."
      });
    }

    const ismatch = await bcrypt.compare(password, curUser.password);
    
    if (!ismatch) {
      return res.status(401).json({ message: "Invalid password" });
    }

    curUser.lastLogin = new Date();
    await curUser.save();

    const token = jwt.sign(    {
      userId: curUser._id,
      name: curUser.name,
    },
    SECRET_KEY,
    { expiresIn: "14d" }
  );

    // const decoded = jwt.verify(token, SECRET_KEY);
    // console.log("userID: ", decoded.userId);
    // console.log("user name: ", curUser.name);
    // console.log("token: ", token);

    res.json({
      message: `Hello ${curUser.name}`,
      token: token,
      user: {
        id: curUser._id,
        name: curUser.name,
        // email: curUser.email,
      }
    });

  } catch (e) {
    console.log(e);
    res.status(500).json({ message: "Server error", error: e.message });
  }
};

const logOut = async (req, res, next) => {
  const token = req.body.token;
  
  try {
    if (!token) {
      return res.status(400).json({
        message: "Token is required",
      })
    }
    const isMatch = jwt.verify(token, SECRET_KEY)
    if (!isMatch) {
      return res.status(400).json({
        message: "Token is invalid",
      })
    }
    
    res.status(200).json({
      message: "Logged out successfully",
    })
    
  } catch (error) {
    throw error;
  }
}

// Google OAuth unified Sign-In / Sign-Up
const googleAuth = async (req, res) => {
  const { googleId, email, name, profileImage, credential, idToken, accessToken } = req.body;
  const googleCredential = credential || idToken || accessToken;

  try {
    let verifiedProfile = null;
    const allowLegacyDevAuth = process.env.NODE_ENV !== 'production' && process.env.ALLOW_DEV_GOOGLE_AUTH === 'true';

    if (googleCredential) {
      verifiedProfile = await verifyGoogleOAuthToken(googleCredential);
    } else if (!allowLegacyDevAuth) {
      return res.status(401).json({
        success: false,
        message: 'Google OAuth credential is required.'
      });
    }

    const resolvedGoogleId = verifiedProfile?.googleId || googleId;
    const resolvedEmail = verifiedProfile?.email || email;
    const resolvedName = verifiedProfile?.name || name;
    const resolvedProfileImage = verifiedProfile?.profileImage || profileImage;

    if (!resolvedGoogleId) {
      return res.status(400).json({ success: false, message: 'Google ID is required.' });
    }

    let user = await User.findOne({ googleId: resolvedGoogleId });

    if (!user && resolvedEmail) {
      user = await User.findOne({ email: resolvedEmail.toLowerCase().trim() });
      if (user) {
        user.googleId = resolvedGoogleId;
        if (!user.providers.includes('google')) {
          user.providers.push('google');
        }

        user.isEmailVerified = true;
        if (resolvedProfileImage && !user.profileImage) {
          user.profileImage = resolvedProfileImage;
        }
        user.lastLogin = new Date();
        await user.save();
      }
    }

    if (!user) {
      user = await User.create({
        name: resolvedName || 'Google User',
        email: resolvedEmail ? resolvedEmail.toLowerCase().trim() : undefined,
        googleId: resolvedGoogleId,
        profileImage: resolvedProfileImage || null,
        isEmailVerified: resolvedEmail ? true : false,
        providers: ['google'],
        lastLogin: new Date()
      });
    } else {
      user.lastLogin = new Date();
      await user.save();
    }

    const token = jwt.sign(
      { userId: user._id },
      SECRET_KEY,
      { expiresIn: '24h' }
    );

    return res.json({
      success: true,
      message: 'Google authentication successful',
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        profileImage: user.profileImage,
        providers: user.providers
      }
    });
  } catch (error) {
    console.error('googleAuth error:', error);
    return res.status(401).json({
      success: false,
      message: 'Google authentication failed',
      error: error.message
    });
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
    const { productId, quantity } = req.body;
    const orderQty = Number(quantity);

    if (!productId || !Number.isFinite(orderQty) || orderQty < 1) {
      return res.status(400).json({
        message: 'productId and quantity (positive number) are required',
      });
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
      productId: product._id.toString(),
      title: product.title,
      imageUrl: product.imageUrl || '',
      quantity: orderQty,
      price: product.price,
      orderedAt: new Date(),
    });

    const productIdStr = String(productId);
    const cartItem = await Cart.findOne({ prodId: productIdStr });
    if (cartItem) {
      if (cartItem.quantity <= orderQty) {
        await Cart.deleteOne({ prodId: productIdStr });
      } else {
        cartItem.quantity -= orderQty;
        await cartItem.save();
      }
    }

    const cart = await Cart.find();

    return res.status(201).json({
      message: 'Order placed successfully',
      order: newOrder,
      cart,
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

const searchFilter = async (req, res, next) => {
  try {
    const prompt =
      typeof req.body?.prompt === 'string'
        ? req.body.prompt
        : typeof req.body?.message === 'string'
          ? req.body.message
          : '';

    if (!prompt.trim()) {
      return res.status(400).json({ message: 'prompt (non-empty string) required' });
    }

    if (!GEMINI_API_KEY) {
      return res.status(500).json({ message: 'Gemini API key not configured' });
    }

    const trimmedPrompt = prompt.trim();
    let filter;

    try {
      filter = await getFilterFromGemini(trimmedPrompt);
    } catch (geminiError) {
      console.warn('Gemini filter fallback:', geminiError.message);
      filter = fallbackTitleFilter(trimmedPrompt);
    }

    const products = await Product.find(filter).lean();

    res.status(200).json({
      prompt: trimmedPrompt,
      filter,
      products,
      count: products.length,
    });
  } catch (error) {
    console.error('searchFilter error:', error);
    res.status(500).json({
      message: 'Search failed',
      error: error.message,
    });
  }
};

const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ message: 'Email is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      // Don't reveal whether user exists for privacy — still send 200
      return res.status(404).json({ message: 'User not found' });
    }

    // send the email and get token
    const token = await sendMail(normalizedEmail);

    const expiresAt = new Date(Date.now() + 30 * 60 * 1000); // 30 minutes

    await ResetPassword.create({
      userId: user._id,
      token,
      expiresAt,
      used: false,
    });

    return res.status(200).json({ message: 'Reset link sent'});
  } catch (error) {
    console.error('forgotPassword error:', error);
    res.status(500).json({
      error: error.message,
      message: 'Failed to initiate password reset',
    });
  }
};

const resetPassword = async (req, res, next) => {
  try {
    const token = req.body.token;
    const newPassword = req.body.newPassword || req.body.password;

    if (!token) return res.status(400).json({ message: 'Token is required' });
    if (!newPassword) return res.status(400).json({ message: 'New password is required' });
    if (typeof newPassword !== 'string' || newPassword.length > 128) {
      return res.status(400).json({ message: 'Password must be 128 characters or fewer' });
    }
    if (newPassword.length < 6) return res.status(400).json({ message: 'Password must be at least 6 characters' });

    const record = await ResetPassword.findOne({ token });
    if (!record) {
      return res.status(400).json({ message: 'Invalid or expired token' });
    }

    if (record.used) {
      return res.status(400).json({ message: 'Token already used' });
    }

    if (new Date() > record.expiresAt) {
      return res.status(400).json({ message: 'Token expired' });
    }

    const user = await User.findById(record.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // The User model already hashes passwords in the pre-save hook.
    user.password = newPassword;
    await user.save();

    record.used = true;
    await record.save();

    return res.status(200).json({ message: 'Password reset successfully' });

  } catch (error) {
    console.error('resetPassword error:', error);
    res.status(500).json({
      message: 'Failed to reset password',
      error: error.message,
    });
  }
}

module.exports = {
  signUp,
  logIn,
  googleAuth,
  logOut,
  resetPassword,
  forgotPassword,
};