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

    // Check if already a member
    if (group.members.includes(userId)) {
      return res.status(200).json(group);
    }

    // Check if private group
    if (group.privacy === 'private') {
      if (group.requests && group.requests.includes(userId)) {
        return res.status(200).json({ requested: true, message: 'Join request already pending approval.' });
      }

      await Group.updateOne(
        { _id: group._id },
        { $addToSet: { requests: userId } }
      );
      return res.status(200).json({ requested: true, message: 'Request sent to group admins.' });
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

    // Resolve requests details
    let resolvedRequests = [];
    if (group.requests && group.requests.length > 0) {
      resolvedRequests = await User.find(
        { userId: { $in: group.requests } },
        { userId: 1, username: 1, avatarUrl: 1 }
      );
    }

    res.status(200).json({
      _id: group._id,
      name: group.name,
      code: group.code,
      createdBy: group.createdBy,
      avatarUrl: group.avatarUrl || '',
      admins: group.admins || [],
      isLocked: group.isLocked || false,
      privacy: group.privacy || 'public',
      requests: resolvedRequests,
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

// Update group profile picture (avatar)
router.post('/:groupId/avatar', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { avatarUrl } = req.body;

    if (!groupId) {
      return res.status(400).json({ message: 'GroupId is required.' });
    }

    const group = await Group.findByIdAndUpdate(
      groupId,
      { avatarUrl: avatarUrl || '' },
      { new: true }
    );

    if (!group) {
      return res.status(404).json({ message: 'Group not found.' });
    }

    res.status(200).json(group);
  } catch (error) {
    console.error('Error updating group icon:', error);
    res.status(500).json({ message: 'Failed to update group icon.' });
  }
});

// Promote a member to sub-creator (admin)
router.post('/:groupId/promote', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body;

    const group = await Group.findByIdAndUpdate(
      groupId,
      { $addToSet: { admins: userId } },
      { new: true }
    );

    if (!group) return res.status(404).json({ message: 'Group not found.' });
    res.status(200).json(group);
  } catch (error) {
    console.error('Error promoting user:', error);
    res.status(500).json({ message: 'Failed to promote user.' });
  }
});

// Demote a sub-creator (admin) back to regular member
router.post('/:groupId/demote', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body;

    const group = await Group.findByIdAndUpdate(
      groupId,
      { $pull: { admins: userId } },
      { new: true }
    );

    if (!group) return res.status(404).json({ message: 'Group not found.' });
    res.status(200).json(group);
  } catch (error) {
    console.error('Error demoting user:', error);
    res.status(500).json({ message: 'Failed to demote user.' });
  }
});

// Kick/remove a user from the group
router.post('/:groupId/kick', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body;

    const group = await Group.findByIdAndUpdate(
      groupId,
      { $pull: { members: userId, admins: userId } },
      { new: true }
    );

    if (!group) return res.status(404).json({ message: 'Group not found.' });

    // Emit live kick event via global socket connection if available
    const io = req.app.get('socketio');
    if (io) {
      io.emit('user_kicked', { groupId, userId });
    }

    res.status(200).json(group);
  } catch (error) {
    console.error('Error kicking user:', error);
    res.status(500).json({ message: 'Failed to remove user.' });
  }
});

// Lock/unlock group chat sending permissions
router.post('/:groupId/lock', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { isLocked } = req.body;

    const group = await Group.findByIdAndUpdate(
      groupId,
      { isLocked: !!isLocked },
      { new: true }
    );

    if (!group) return res.status(404).json({ message: 'Group not found.' });

    // Emit live group settings update via socket
    const io = req.app.get('socketio');
    if (io) {
      io.to(groupId).emit('group_settings_updated', {
        groupId,
        isLocked: group.isLocked,
        privacy: group.privacy,
      });
    }

    res.status(200).json(group);
  } catch (error) {
    console.error('Error locking group:', error);
    res.status(500).json({ message: 'Failed to update lock settings.' });
  }
});

// Set group privacy (public/private)
router.post('/:groupId/privacy', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { privacy } = req.body;

    const group = await Group.findByIdAndUpdate(
      groupId,
      { privacy },
      { new: true }
    );

    if (!group) return res.status(404).json({ message: 'Group not found.' });

    // Emit live group settings update via socket
    const io = req.app.get('socketio');
    if (io) {
      io.to(groupId).emit('group_settings_updated', {
        groupId,
        isLocked: group.isLocked,
        privacy: group.privacy,
      });
    }

    res.status(200).json(group);
  } catch (error) {
    console.error('Error setting group privacy:', error);
    res.status(500).json({ message: 'Failed to update privacy settings.' });
  }
});

// Approve a user's join request
router.post('/:groupId/requests/accept', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body;

    // Pull from requests and addToSet in members atomically
    const group = await Group.findByIdAndUpdate(
      groupId,
      { 
        $pull: { requests: userId },
        $addToSet: { members: userId }
      },
      { new: true }
    );

    if (!group) return res.status(404).json({ message: 'Group not found.' });

    // Emit live acceptance event to the user's client so they re-fetch lists
    const io = req.app.get('socketio');
    if (io) {
      io.emit('request_accepted', { groupId, userId });
    }

    res.status(200).json(group);
  } catch (error) {
    console.error('Error accepting request:', error);
    res.status(500).json({ message: 'Failed to approve join request.' });
  }
});

// Reject/decline a user's join request
router.post('/:groupId/requests/reject', async (req, res) => {
  try {
    const { groupId } = req.params;
    const { userId } = req.body;

    const group = await Group.findByIdAndUpdate(
      groupId,
      { $pull: { requests: userId } },
      { new: true }
    );

    if (!group) return res.status(404).json({ message: 'Group not found.' });
    res.status(200).json(group);
  } catch (error) {
    console.error('Error rejecting request:', error);
    res.status(500).json({ message: 'Failed to decline request.' });
  }
});

// Delete a group permanently and clean up all associated messages
router.delete('/:groupId', async (req, res) => {
  try {
    const { groupId } = req.params;

    const group = await Group.findById(groupId);
    if (!group) return res.status(404).json({ message: 'Group not found.' });

    // Delete group document
    await Group.findByIdAndDelete(groupId);

    // Delete all messages belonging to this group
    const Message = require('../models/Message');
    await Message.deleteMany({ groupId });

    // Emit live delete notification to everyone inside the group room
    const io = req.app.get('socketio');
    if (io) {
      io.to(groupId).emit('group_deleted', { groupId });
    }

    res.status(200).json({ message: 'Group deleted successfully.' });
  } catch (error) {
    console.error('Error deleting group:', error);
    res.status(500).json({ message: 'Failed to delete group.' });
  }
});

module.exports = router;
