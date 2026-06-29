const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  messageId: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  groupId: {
    type: String,
    required: true,
    index: true,
  },
  senderId: {
    type: String,
    required: true,
  },
  senderName: {
    type: String,
    required: true,
  },
  text: {
    type: String,
    required: true,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Message', messageSchema);
