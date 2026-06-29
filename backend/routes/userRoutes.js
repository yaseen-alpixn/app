const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { sanitizeText } = require('../utils/sanitize');

// Create or update user profile
router.post('/profile', async (req, res) => {
  try {
    const { userId, username, avatarUrl, pushToken } = req.body;

    if (!userId || !username) {
      return res.status(400).json({ message: 'userId and username are required.' });
    }

    const sanitizedUsername = sanitizeText(username);
    if (!sanitizedUsername) {
      return res.status(400).json({ message: 'Username cannot be blank.' });
    }

    // Atomic upsert
    const user = await User.findOneAndUpdate(
      { userId },
      {
        username: sanitizedUsername,
        avatarUrl: avatarUrl || '',
        pushToken: pushToken || ''
      },
      { new: true, upsert: true, runValidators: true }
    );

    res.status(200).json(user);
  } catch (error) {
    console.error('Error in user profile updates:', error);
    res.status(500).json({ message: 'Failed to update user profile.' });
  }
});

module.exports = router;
