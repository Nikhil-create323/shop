const mongoose = require('mongoose');
const Schema = mongoose.Schema;
const bcrypt = require('bcrypt');

const userSchema = new Schema({
  // Basic Profile
  name: {
    type: String,
    required: true,
    trim: true
  },

  profileImage: {
    type: String,
    default: null
  },

  // Email Auth
  email: {
    type: String,
    unique: true,
    sparse: true,
    lowercase: true,
    trim: true
  },

  isEmailVerified: {
    type: Boolean,
    default: false
  },

  // Phone Auth
  phone: {
    type: String,
    unique: true,
    sparse: true
  },

  isPhoneVerified: {
    type: Boolean,
    default: false
  },

  // Password
  // null allowed for Google/OTP-only users
  password: {
    type: String,
    default: null
  },

  // Connected Login Methods
  // ["email"]
  // ["google"]
  // ["google", "email"]
  providers: {
    type: [String],
    enum: ["email", "phone", "google"],
    required: true
  },

  // Google OAuth
  googleId: {
    type: String,
    default: null
  },

  // Optional App Fields
  role: {
    type: String,
    default: "user"
  },

  isBlocked: {
    type: Boolean,
    default: false
  },

  lastLogin: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

// Pre-save hook to hash password using bcrypt when modified
userSchema.pre('save', async function () {

  if (!this.isModified('password') || !this.password) {
    return;
  }

  const salt = await bcrypt.genSalt(10);

  this.password = await bcrypt.hash(this.password, salt);
});

module.exports = mongoose.model("User", userSchema);