const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const cartSchema = new Schema({
    userID: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    
    prodId: String,
    quantity: Number,
    user: String,
});



module.exports = mongoose.model("Cart", cartSchema);