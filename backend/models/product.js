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
});

module.exports = mongoose.model('Product', productSchema);