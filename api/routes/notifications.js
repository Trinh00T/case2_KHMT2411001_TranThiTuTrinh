
const express = require('express');
const mongoose = require('mongoose');

const Notification = require('../models/Notification');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Lấy danh sách thông báo của tài khoản đang đăng nhập
router.get('/', async (req, res) => {
  try {
    const notifications = await Notification.find({
      recipient: req.user._id
    })
      .populate('sender', 'name email')
      .populate('task', 'title status')
      .sort({ createdAt: -1 });

    return res.json({
      success: true,
      notifications
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Khong the lay danh sach thong bao',
      error: error.message
    });
  }
});

// Đếm số thông báo chưa đọc
router.get('/unread-count', async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      recipient: req.user._id,
      isRead: false
    });

    return res.json({
      success: true,
      count
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Khong the dem thong bao chua doc',
      error: error.message
    });
  }
});

// Đánh dấu một thông báo đã đọc
router.patch('/:id/read', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'ID thong bao khong hop le'
      });
    }

    const notification = await Notification.findOneAndUpdate(
      {
        _id: req.params.id,
        recipient: req.user._id
      },
      { isRead: true },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay thong bao'
      });
    }

    return res.json({
      success: true,
      message: 'Da danh dau thong bao',
      notification
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Khong the cap nhat thong bao',
      error: error.message
    });
  }
});

// Đánh dấu tất cả thông báo đã đọc
router.patch('/read-all', async (req, res) => {
  try {
    await Notification.updateMany(
      {
        recipient: req.user._id,
        isRead: false
      },
      { isRead: true }
    );

    return res.json({
      success: true,
      message: 'Da danh dau tat ca thong bao'
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Khong the cap nhat thong bao',
      error: error.message
    });
  }
});

module.exports = router;
