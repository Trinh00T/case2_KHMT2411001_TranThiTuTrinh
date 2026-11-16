
const mongoose = require('mongoose');

// Người dùng đã đăng ký được chia sẻ
const taskShareSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    permission: {
      type: String,
      enum: ['viewer', 'editor'],
      default: 'viewer'
    }
  },
  { _id: false }
);

// Email chưa đăng ký được mời chia sẻ
const externalShareSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true
    },
    permission: {
      type: String,
      enum: ['viewer', 'editor'],
      default: 'viewer'
    },
    status: {
      type: String,
      enum: ['pending', 'sent', 'failed'],
      default: 'pending'
    },
    sentAt: {
      type: Date,
      default: null
    }
  },
  { timestamps: true }
);

const taskSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true
    },
    description: {
      type: String,
      default: ''
    },
    status: {
      type: String,
      default: 'Chưa thực hiện'
    },
    priority: {
      type: String,
      default: 'Trung bình'
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    },
    assignee: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null
    },
    assignees: {
      type: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
      }],
      default: []
    },

    // Người dùng đã đăng ký
    sharedWith: {
      type: [taskShareSchema],
      default: []
    },

    // Người được giao việc qua email
    externalAssignees: {
      type: [
        {
          email: {
            type: String,
            required: true,
            lowercase: true,
            trim: true
          },
          status: {
            type: String,
            enum: ['sent', 'failed'],
            default: 'sent'
          },
          sentAt: {
            type: Date,
            default: Date.now
          }
        }
      ],
      default: []
    },

    // Người chưa đăng ký được mời chia sẻ
    externalSharedWith: {
      type: [externalShareSchema],
      default: []
    },

    startDate: {
      type: Date,
      default: Date.now
    },
    dueDate: {
      type: Date,
      required: true
    }
  },
  { timestamps: true }
);

module.exports = mongoose.model('Task', taskSchema);
