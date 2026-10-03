const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  sku: {
    type: String,
    unique: true,
    sparse: true,
  },

  title: String,

  price: Number,

  imageUrl: String,

  stock: {
    type: Number,
    default: 10,
  },

  costPrice: {
    type: Number,
    default: 0,
  },

  discountPercentage: {
    type: Number,
    default: 0,
    min: 0,
    max: 100,
  },

  offerTitle: {
    type: String,
    default: '',
  },
});

module.exports = mongoose.model('Product', productSchema);