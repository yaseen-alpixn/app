const express = require('express');
const router = express.Router();
const Group = require('../models/Group');
const User = require('../models/User');
const Message = require('../models/Message');
const { sanitizeText } = require('../utils/sanitize');

// Helper to generate a 6-digit uppercase alphanumeric code
const generateCode = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
};

// Helper to ensure code is unique in the database
const generateUniqueCode = async () => {
  let code;
  let exists = true;
  while (exists) {
    code = generateCode();
    const count = await Group.countDocuments({ code });
    if (count === 0) {
      exists = false;
    }
  }
  return code;
};

// Create a new group
router.post('/create', async (req, res) => {
  try {
    const { name, creatorId } = req.body;

    if (!name || !creatorId) {
      return res.status(400).json({ message: 'Group name and creatorId are required.' });
    }

    const sanitizedName = sanitizeText(name);
    if (!sanitizedName) {
      return res.status(400).json({ message: 'Group name cannot be blank.' });
    }

    // Verify creator exists (or register placeholder if not)
    const creatorExists = await User.findOne({ userId: creatorId });
    if (!creatorExists) {
      return res.status(400).json({ message: 'Creator profile must be configured first.' });
    }

    const uniqueCode = await generateUniqueCode();

    const newGroup = new Group({
      name: sanitizedName,
      code: uniqueCode,
      members: [creatorId],
      createdBy: creatorId
    });

    await newGroup.save();
    res.status(201).json(newGroup);
  } catch (error) {
    console.error('Error creating group:', error);
    res.status(500).json({ message: 'Failed to create group.' });
  }
});

// Join group via 6-digit invite code (Case-insensitive)
router.post('/join', async (req, res) => {
  try {
    const { code, userId } = req.body;

    if (!code || !userId) {
      return res.status(400).json({ message: 'Code and userId are required.' });
    }

    // Sanitize and force uppercase for case insensitivity
    const sanitizedCode = code.trim().toUpperCase();

    // Verify user profile exists
    const userExists = await User.findOne({ userId });
    if (!userExists) {
      return res.status(400).json({ message: 'Please set up your profile name before joining groups.' });
    }

    // Find group
    const group = await Group.findOne({ code: sanitizedCode });
    if (!group) {
      return res.status(404).json({ message: 'Invalid Group Code. Please check and try again.' });
    }

    // Atomically add user to members list (prevents duplicates automatically)
    await Group.updateOne(
      { _id: group._id },
      { $addToSet: { members: userId } }
    );

    // Fetch the updated group
    const updatedGroup = await Group.findById(group._id);
    res.status(200).json(updatedGroup);
  } catch (error) {
    console.error('Error joining group:', error);
    res.status(500).json({ message: 'Failed to join group.' });
  }
});

// Fetch all groups where user is a member
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const groups = await Group.find({ members: userId }).sort({ updatedAt: -1 });
    res.status(200).json(groups);
  } catch (error) {
    console.error('Error fetching user groups:', error);
    res.status(500).json({ message: 'Failed to retrieve groups.' });
  }
});

// Fetch group details along with resolved member display names
router.get('/:groupId/details', async (req, res) => {
  try {
    const { groupId } = req.params;

    const group = await Group.findById(groupId);
    if (!group) {
      return res.status(404).json({ message: 'Group not found.' });
    }

    // Resolve member details
    const resolvedMembers = await User.find(
      { userId: { $in: group.members } },
      { userId: 1, username: 1, avatarUrl: 1 }
    );

    res.status(200).json({
      _id: group._id,
      name: group.name,
      code: group.code,
      createdBy: group.createdBy,
      members: resolvedMembers,
      createdAt: group.createdAt
    });
  } catch (error) {
    console.error('Error fetching group details:', error);
    res.status(500).json({ message: 'Failed to fetch group details.' });
  }
});

// Fetch last 100 messages for a specific group
router.get('/:groupId/messages', async (req, res) => {
  try {
    const { groupId } = req.params;
    const messages = await Message.find({ groupId })
      .sort({ timestamp: 1 })
      .limit(100);
    res.status(200).json(messages);
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ message: 'Failed to retrieve chat messages.' });
  }
});

module.exports = router;
