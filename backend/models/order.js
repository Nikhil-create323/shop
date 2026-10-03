const mongoose =  require("mongoose");
const Schema =  mongoose.Schema;

const orderSchema = new Schema({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  productId: {
    type: Schema.Types.ObjectId,
    ref: 'Product',
    required: true
  },

  title: {
    type: String,
    required: true
  },

  imageUrl: {
    type: String,
    required: true
  },

  quantity: {
    type: Number,
    required: true,
    min: 1
  },

  price: {
    type: Number,
    required: true
  },

  paymentIntentId: {
    type: String,
    required: false,
  },

  status: {
    type: String,
    enum: [
      'placed',
      'cancelling',
      'cancelled',
      'return_requested',
      'return_processing',
      'return_rejected',
      'returned',
    ],
    default: 'placed',
  },

  refundId: {
    type: String,
  },

  orderedAt: {
    type: Date,
    default: Date.now
  }
}
);

module.exports = mongoose.model("Order", orderSchema);