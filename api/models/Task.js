
const mongoose = require('mongoose');

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
    sharedWith: {
      type: [taskShareSchema],
      default: []
    },
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
