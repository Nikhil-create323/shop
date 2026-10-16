# Shop App

A full-stack e-commerce application built with a **Flutter mobile frontend** and a **Node.js/Express backend** with MongoDB. The app supports user authentication, product browsing, cart management, order placement, Stripe payments, reviews, and admin dashboard operations.

## Features

- **Authentication:** User signup/login with email and Google authentication.
- **Password Reset:** Forgot-password and password-reset flow.
- **Product Catalog:** Product browsing with custom filtering, including natural-language-to-database query support.
- **Shopping Cart:** Add and remove products from the cart.
- **Order Management:** Order placement, order history, cancellation, and return requests.
- **Payments:** Stripe-based payment intent and checkout flow.
- **Reviews and Ratings:** Product reviews, ratings, and AI-powered review summaries.
- **Admin Dashboard:** Product management and return request handling.
- **AI Product Assistant:** AI-inspired product search and assistant support.
- **Notifications:** Firebase Cloud Messaging (FCM) setup for notifications.

## Tech Stack

| Component | Technology |
|---|---|
| Frontend | Flutter, Dart |
| Backend | Node.js, Express.js |
| Database | MongoDB, Mongoose |
| Payments | Stripe |
| Authentication | JWT, Google OAuth |
| Notifications | Firebase Cloud Messaging |
| API Validation | express-validator |
| Security | Rate limiting, CORS, JWT-based authentication |

## Project Structure

shop/
├── backend/
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   ├── utils/
│   ├── index.js
│   └── package.json
├── frontend/
│   ├── lib/
│   ├── android/
│   ├── ios/
│   ├── pubspec.yaml
│   └── README.md
├── package.json
└── README.md

## Backend Setup

### 1. Navigate to the Backend Directory
cd backend

### 2. Install Dependencies
npm install


### 3. Configure Environment Variables
Create a `.env` file inside the `backend/` directory:
PORT=3000

MONGODB_URI=mongodb://localhost:27017/shop

SECRET_KEY=your-super-secret-key

FRONTEND_URL=http://localhost:3000

STRIPE_API_KEY=sk_test_your_stripe_secret_key

GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_REDIRECT_URI=http://localhost:3000/oauth2callback

**Important:** Replace the placeholder values with your actual configuration. Keep your `.env` file private and never commit real API keys, OAuth secrets, or Stripe secret keys to version control.

### 4. Start the Backend
npm start

The backend API will run at:
http://localhost:3000


**Deployed application:** [shop-olive-one.vercel.app](https://shop-olive-one.vercel.app)
## Frontend Setup

### 1. Navigate to the Frontend Directory

From the project root:
cd frontend

### 2. Install Flutter Dependencies
flutter pub get

### 3. Run the Application
flutter run

If needed, specify the API base URL using a Dart environment variable:
flutter run --dart-define=AI_BASE_URL=http://localhost:3000

**Note:** `localhost` refers to the device or emulator running the Flutter app. For a physical device, use your computer's LAN IP address. Android emulators commonly use `10.0.2.2` to access the host machine's localhost.

## Main API Endpoints

### Authentication

| Method | Endpoint | Description |
|---|---|---|
| POST | `/signup` | Register
