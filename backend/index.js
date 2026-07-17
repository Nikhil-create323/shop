// 1. ENVIRONMENT CONFIGURATION
require('dotenv').config();
const Mailer = require('./utils/mailer.js');
const dns = require('dns');

dns.setDefaultResultOrder("ipv4first");

// 2. CORE & THIRD-PARTY MODULES
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const { google } = require('googleapis');

// 3. LOCAL MODELS & ROUTES
const User = require('./models/user.js');
// const Cart = require('./models/cart.js');
const userRoutes = require('./routes/user.js');

// 4. APP INITIALIZATION & CONSTANTS
const app = express();
const SECRET_KEY = "secret key";



// 5. MIDDLEWARE
app.set('trust proxy', 1);
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests from this IP, please try again later.' },
});

app.use(cors()); // Handles Cross-Origin Resource Sharing
app.use(globalLimiter);
app.use(express.json({ limit: '12kb' })); // Protect against overly large payloads
app.use(express.urlencoded({ extended: true, limit: '12kb' }));


// const gmailController = require('./controllers/gmail.js');


app.use(userRoutes); // Injected User Routes

// 9. DATABASE CONNECTION & SERVER START
// const password = encodeURIComponent(process.env.MONGODB_PASSWORD);
const PORT = process.env.PORT;

mongoose
  .connect(
    process.env.MONGODB_URI,
  )
  .then(() => {
    console.log('mongoDB Connected');
    app.listen(PORT, () => {
      console.log(`Example app listening on port ${PORT}`);
    });
  })
  .catch((e) => console.error('MongoDB connection failed:', e));