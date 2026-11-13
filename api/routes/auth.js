const authMiddleware = require('../middleware/auth');
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const router = express.Router();

// ================= ĐĂNG KÝ =================
router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Vui long nhap day du thong tin'
      });
    }

    if (password.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'Mat khau phai co it nhat 8 ky tu'
      });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const existingUser = await User.findOne({
      email: normalizedEmail
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Email da duoc dang ky'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 12);

    const user = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      password: hashedPassword
    });

    return res.status(201).json({
      success: true,
      message: 'Dang ky tai khoan thanh cong',
      user: {
        id: user._id,
        name: user.name,
        email: user.email
      }
    });
  } catch (error) {
    console.error('Loi dang ky:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Loi may chu'
    });
  }
});

// ================= ĐĂNG NHẬP =================
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Vui long nhap email va mat khau'
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase()
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Email hoac mat khau khong dung'
      });
    }

    const isMatch = await bcrypt.compare(
      password,
      user.password
    );

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Email hoac mat khau khong dung'
      });
    }

    if (!process.env.JWT_SECRET) {
      throw new Error('JWT_SECRET chua duoc cau hinh trong .env');
    }

    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET,
      { expiresIn: '1d' }
    );

    return res.json({
      success: true,
      message: 'Dang nhap thanh cong',
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email
      }
    });
  } catch (error) {
    console.error('Loi dang nhap:', error.message);

    return res.status(500).json({
      success: false,
      message: 'Loi may chu'
    });
  }
});
// Cap nhat thong tin ca nhan
router.patch('/profile', authMiddleware, async (req, res) => {
  try {
    const { name, email } = req.body;

    if (!name || !email) {
      return res.status(400).json({
        success: false,
        message: 'Vui long nhap day du ho ten va email'
      });
    }

    const normalizedName = name.trim();
    const normalizedEmail = email.trim().toLowerCase();

    if (!normalizedName || !normalizedEmail) {
      return res.status(400).json({
        success: false,
        message: 'Ho ten va email khong duoc de trong'
      });
    }

    const existingUser = await User.findOne({
      email: normalizedEmail,
      _id: { $ne: req.user._id }
    });

    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Email nay da duoc su dung boi tai khoan khac'
      });
    }

    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay tai khoan'
      });
    }

    user.name = normalizedName;
    user.email = normalizedEmail;

    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Cap nhat thong tin ca nhan thanh cong',
      user: {
        id: user._id,
        name: user.name,
        email: user.email
      }
    });
  } catch (error) {
    console.error('Loi cap nhat ho so:', error);

    return res.status(500).json({
      success: false,
      message: 'Loi server khi cap nhat thong tin ca nhan'
    });
  }
});
module.exports = router;
