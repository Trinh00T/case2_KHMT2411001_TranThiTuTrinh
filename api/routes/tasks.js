
const express = require('express');
const mongoose = require('mongoose');
const Task = require('../models/Task');
const verifyToken = require('../middleware/auth');

const router = express.Router();

router.use(verifyToken);

// 1. Lay danh sach cong viec
router.get('/', async (req, res) => {
  try {
    const tasks = await Task.find({ user: req.userId })
      .sort({ createdAt: -1 });

    res.json({ success: true, data: tasks });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Loi may chu'
    });
  }
});

// 2. Them cong viec
router.post('/', async (req, res) => {
  try {
    const { title, description, status, dueDate } = req.body;

    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Ten cong viec khong duoc de trong'
      });
    }

    const task = await Task.create({
      title: title.trim(),
      description,
      status,
      dueDate: dueDate || null,
      user: req.userId
    });

    res.status(201).json({
      success: true,
      message: 'Them cong viec thanh cong',
      data: task
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      message: 'Du lieu cong viec khong hop le'
    });
  }
});

// 3. Cap nhat cong viec
router.put('/:id', async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'ID cong viec khong hop le'
      });
    }

    const allowedFields = ['title', 'description', 'status', 'dueDate'];
    const updates = {};

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    }

    if (updates.title !== undefined) {
      if (typeof updates.title !== 'string' || !updates.title.trim()) {
        return res.status(400).json({
          success: false,
          message: 'Ten cong viec khong hop le'
        });
      }
      updates.title = updates.title.trim();
    }

    const task = await Task.findOneAndUpdate(
      { _id: req.params.id, user: req.userId },
      updates,
      { new: true, runValidators: true }
    );

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    res.json({
      success: true,
      message: 'Cap nhat cong viec thanh cong',
      data: task
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      message: 'Du lieu cong viec khong hop le'
    });
  }
});

// 4. Xoa cong viec
router.delete('/:id', async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'ID cong viec khong hop le'
      });
    }

    const task = await Task.findOneAndDelete({
      _id: req.params.id,
      user: req.userId
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    res.json({
      success: true,
      message: 'Xoa cong viec thanh cong'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Loi may chu'
    });
  }
});

module.exports = router;
