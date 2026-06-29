const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  username: {
    type: String,
    required: true,
    trim: true,
  },
  avatarUrl: {
    type: String,
    default: '',
  },
  pushToken: {
    type: String,
    default: '',
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', userSchema);
