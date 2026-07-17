const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const cartSchema = new Schema({
    prodId: String,
    quantity: Number,
    user: String,
});



module.exports = mongoose.model("Cart", cartSchema);