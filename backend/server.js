const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
require('dotenv').config();

const connectDB = require('./config/db');
const userRoutes = require('./routes/userRoutes');
const groupRoutes = require('./routes/groupRoutes');
const Message = require('./models/Message');
const User = require('./models/User');
const Group = require('./models/Group');
const { sanitizeText } = require('./utils/sanitize');

// Initialize database
connectDB();

const app = express();
const server = http.createServer(app);

// Configure Socket.io with permissive CORS for mobile clients
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  }
});
app.set('socketio', io);

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/users', userRoutes);
app.use('/api/groups', groupRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.status(200).send('VASL Backend Server is running.');
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', env: process.env.NODE_ENV });
});

// Real-time Socket Connection State Mapping
const activeUsers = new Map(); // Maps userId -> socketId

// Socket.io Logic
io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}`);

  // 1. Register active user identity to socket connection
  socket.on('register_user', ({ userId }) => {
    if (userId) {
      activeUsers.set(userId, socket.id);
      socket.userId = userId;
      console.log(`User registered: ${userId} -> Socket: ${socket.id}`);
    }
  });

  // 2. Join a group chat room
  socket.on('join_room', ({ groupId, userId }) => {
    if (groupId) {
      socket.join(groupId);
      console.log(`User ${userId || socket.id} joined room: ${groupId}`);
    }
  });

  // 3. Handle incoming message broadcast
  socket.on('send_message', async (payload, callback) => {
    try {
      const { messageId, groupId, senderId, senderName, text, timestamp, type, fileUrl, fileName } = payload;

      if (!messageId || !groupId || !senderId || !senderName) {
        if (callback) callback({ error: 'Missing message fields.' });
        return;
      }

      // Check if group is locked and restrict post permissions
      const group = await Group.findById(groupId);
      if (group && group.isLocked) {
        const isCreator = group.createdBy === senderId;
        const isAdmin = group.admins && group.admins.includes(senderId);
        if (!isCreator && !isAdmin) {
          if (callback) callback({ error: 'This group is locked. Only admins can send messages.' });
          return;
        }
      }

      const msgType = type || 'text';
      const fileLink = fileUrl || '';
      const docName = fileName || '';

      // If it's a text message or has a caption, sanitize it
      let sanitizedText = '';
      if (text && text.trim().length > 0) {
        sanitizedText = sanitizeText(text);
      }

      // If it is text type and has no text content, reject
      if (msgType === 'text' && !sanitizedText) {
        if (callback) callback({ error: 'Message content cannot be blank.' });
        return;
      }

      // Create message in database
      const newMessage = new Message({
        messageId,
        groupId,
        senderId,
        senderName,
        text: sanitizedText,
        type: msgType,
        fileUrl: fileLink,
        fileName: docName,
        timestamp: timestamp ? new Date(timestamp) : new Date(),
      });

      await newMessage.save();

      // Emit message payload to everyone in the room (including sender)
      const broadcastPayload = {
        messageId,
        groupId,
        senderId,
        senderName,
        text: sanitizedText,
        type: msgType,
        fileUrl: fileLink,
        fileName: docName,
        timestamp: newMessage.timestamp.toISOString(),
      };

      io.to(groupId).emit('receive_message', broadcastPayload);

      // Return success acknowledgement to the sender client
      if (callback) {
        callback({ success: true, message: broadcastPayload });
      }

      // Fallback Push Notifications logic for offline room members
      const pushText = msgType === 'text' 
          ? sanitizedText 
          : msgType === 'image' 
              ? 'Shared an image' 
              : 'Shared a file';
      processOfflineNotifications(groupId, senderName, pushText, senderId);

    } catch (error) {
      console.error('Error handling socket message:', error);
      if (callback) callback({ error: 'Server failed to deliver message.' });
    }
  });

  // 4. Disconnect handling
  socket.on('disconnect', () => {
    if (socket.userId) {
      activeUsers.delete(socket.userId);
      console.log(`User registered as ${socket.userId} disconnected.`);
    } else {
      console.log(`Socket disconnected: ${socket.id}`);
    }
  });
});

// Helper function to process push notifications for group members not currently online
async function processOfflineNotifications(groupId, senderName, text, senderId) {
  try {
    const group = await Group.findById(groupId);
    if (!group) return;

    // Find group members who are NOT registered in activeUsers
    const offlineMembers = group.members.filter(memberId => memberId !== senderId && !activeUsers.has(memberId));

    if (offlineMembers.length === 0) return;

    // Find push tokens for these offline users
    const users = await User.find({ userId: { $in: offlineMembers } }, { pushToken: 1, username: 1 });

    users.forEach(user => {
      if (user.pushToken) {
        console.log(`[Push Notification Fallback] Sending push to ${user.username} (Token: ${user.pushToken}) -> "${senderName}: ${text}"`);
        // Here we would integrate firebase-admin messaging:
        // admin.messaging().sendToDevice(user.pushToken, { notification: { title: group.name, body: `${senderName}: ${text}` } })
      }
    });
  } catch (error) {
    console.error('Failed to process offline notifications:', error);
  }
}

// Start Server
const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`VASL Backend running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
});
