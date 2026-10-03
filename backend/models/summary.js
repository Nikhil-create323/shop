const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const summarySchema = new Schema({
    summary: {
        type: String,
        default: ''
    },
    prodId: {
        type: String,
        required: true,
        index: true
    },
    
    buffer: {
        type: [String],
        default: []
    }
});

module.exports = mongoose.model("Summary", summarySchema);