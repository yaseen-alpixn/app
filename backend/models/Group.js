const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  code: {
    type: String,
    required: true,
    unique: true,
    index: true,
    uppercase: true, // Auto-converts group code to uppercase in DB
  },
  members: [{
    type: String, // Stored as User userId strings
  }],
  createdBy: {
    type: String,
    required: true,
  },
  avatarUrl: {
    type: String,
    default: '',
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Group', groupSchema);
