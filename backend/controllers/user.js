const jwt = require('jsonwebtoken');
require('dotenv').config();

const bcrypt = require('bcrypt');
const twilio = require('twilio');

const User = require('../models/user');
const Order = require('../models/order');
const Cart = require('../models/cart');
const ResetPassword = require('../models/password-reset');

const {sendMail} = require('./gmail');
// const { findProductById, fetchProducts, seedProducts } = require('./product');


const SECRET_KEY = process.env.SECRET_KEY || 'your-secret-key-change-this';


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

    const decoded = jwt.verify(token, SECRET_KEY);
    console.log("userID: ", decoded.userId);
    console.log("user name: ", curUser.name);
    console.log("token: ", token);

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

// Send OTP via Twilio
const sendOtp = async (req, res) => {
  const { phone } = req.body;

  if (!phone) {
    return res.status(400).json({
      success: false,
      message: 'Phone number is required.'
    });
  }

  try {
    const otp = generateOTP();
    const expiryTime = Date.now() + 5 * 60 * 1000; // 5 minutes

    otpStore[phone] = {
      otp,
      expiresAt: expiryTime
    };

    console.log(`[OTP Services] Generated OTP for ${phone}: ${otp}`);

    if (twilioClient) {
      let formattedPhone = phone.trim();
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = `+91${formattedPhone}`; // Default to India country code
      }

      await twilioClient.messages.create({
        body: `Your verification code is ${otp}.`,
        from: twilioPhoneNumber,
        to: formattedPhone
      });

      return res.json({
        success: true,
        message: 'OTP sent successfully via SMS'
      });
    } else {
      // Development mode
      return res.json({
        success: true,
        message: 'OTP sent successfully (Development Mode)',
        otp: otp
      });
    }

  } catch (error) {
    console.error("Failed to send OTP:", error);
    return res.status(500).json({
      success: false,
      message: 'Failed to send OTP',
      error: error.message
    });
  }
};

// Verify OTP and Login/Signup
const verifyOtp = async (req, res) => {
  const { phone, otp, name } = req.body;

  if (!phone || !otp) {
    return res.status(400).json({ success: false, message: 'Phone number and OTP are required.' });
  }

  const record = otpStore[phone];

  if (!record) {
    return res.status(400).json({ success: false, message: 'No OTP requested for this number.' });
  }

  // Check expiration
  if (Date.now() > record.expiresAt) {
    delete otpStore[phone]; // Clean up
    return res.status(400).json({ success: false, message: 'OTP has expired.' });
  }

  // Check matching OTP
  if (record.otp !== otp) {
    return res.status(400).json({ success: false, message: 'Incorrect OTP.' });
  }

  // OTP verified! Clean up
  delete otpStore[phone];

  try {
    let user = await User.findOne({ phone: phone.trim() });

    if (user) {
      // Link phone provider if not already present
      if (!user.providers.includes("phone")) {
        user.providers.push("phone");
      }
      user.isPhoneVerified = true;
      user.lastLogin = new Date();
      await user.save();
    } else {
      // Create new user
      user = await User.create({
        name: name || `User ${phone.slice(-4)}`,
        phone: phone.trim(),
        isPhoneVerified: true,
        providers: ["phone"],
        lastLogin: new Date()
      });
    }

    const token = jwt.sign(
      { userId: user._id },
      SECRET_KEY,
      { expiresIn: "24h" }
    );

    return res.json({
      success: true,
      message: 'OTP verified successfully!',
      token: token,
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone,
        providers: user.providers
      }
    });

  } catch (error) {
    console.error("verifyOtp error:", error);
    return res.status(500).json({
      success: false,
      message: 'Failed to verify OTP and login',
      error: error.message
    });
  }
};

// Google OAuth unified Sign-In / Sign-Up
const googleAuth = async (req, res) => {
  const { googleId, email, name, profileImage } = req.body;

  if (!googleId) {
    return res.status(400).json({ success: false, message: 'Google ID is required.' });
  }

  try {
    let user = await User.findOne({ googleId });

    if (!user && email) {
      user = await User.findOne({ email: email.toLowerCase().trim() });
      if (user) {
        // Link google credentials to existing account
        user.googleId = googleId;
        if (!user.providers.includes("google")) {
          user.providers.push("google");
        }
        user.isEmailVerified = true;
        if (profileImage && !user.profileImage) {
          user.profileImage = profileImage;
        }
        user.lastLogin = new Date();
        await user.save();
      }
    }

    if (!user) {
      // Create new user
      user = await User.create({
        name: name || 'Google User',
        email: email ? email.toLowerCase().trim() : undefined,
        googleId,
        profileImage: profileImage || null,
        isEmailVerified: email ? true : false,
        providers: ["google"],
        lastLogin: new Date()
      });
    } else {
      user.lastLogin = new Date();
      await user.save();
    }

    const token = jwt.sign(
      { userId: user._id },
      SECRET_KEY,
      { expiresIn: "24h" }
    );

    return res.json({
      success: true,
      message: 'Google authentication successful',
      token: token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        profileImage: user.profileImage,
        providers: user.providers
      }
    });

  } catch (error) {
    console.error("googleAuth error:", error);
    return res.status(500).json({
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
  sendOtp,
  verifyOtp,
  googleAuth,
  logOut,
  resetPassword,
  // changePassword,
  forgotPassword,
};