// 1. ENVIRONMENT CONFIGURATION
require('dotenv').config();
const dns = require('dns');

dns.setDefaultResultOrder("ipv4first");

// 2. CORE & THIRD-PARTY MODULES
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { google } = require('googleapis');

// 3. LOCAL MODELS & ROUTES
const userRoutes = require('./routes/user.js');

// 4. APP INITIALIZATION & CONSTANTS
const app = express();
app.set('trust proxy', 1);

// 5. MIDDLEWARE
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests from this IP, please try again later.' },
});


app.use(cors()); // Handles Cross-Origin Resource Sharing
app.use(cors({ origin: '*' }));
app.use(globalLimiter);
app.use(express.json({ limit: '12kb' })); // Protect against overly large payloads
app.use(express.urlencoded({ extended: true, limit: '12kb' }));

const oAuth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI,
);



// app.get('/oauth2callback', async (req, res) => {
//   const code = req.query.code;

//   if (!code) {
//     return res.status(400).send('<h1>Missing code</h1><p>The authorization code is required.</p>');
//   }

//   try {
//     const { tokens } = await oAuth2Client.getToken(code);
//     const refreshToken = tokens.refresh_token || 'No refresh token returned';

//     return res.send(`
//       <h1>Google OAuth2 Callback</h1>
//       <p><strong>Refresh Token:</strong></p>
//       <pre>${refreshToken}</pre>
//       <p><strong>Full Token Response:</strong></p>
//       <pre>${JSON.stringify(tokens, null, 2)}</pre>
//     `);
//   } catch (error) {
//     console.error('oauth2callback error:', error);
//     return res.status(500).send(`<h1>Token exchange failed</h1><pre>${error.message}</pre>`);
//   }
// });

app.use(userRoutes); // Injected User Routes

// 9. DATABASE CONNECTION & SERVER START
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

  module.exports = app; // Export the app for testing or further use