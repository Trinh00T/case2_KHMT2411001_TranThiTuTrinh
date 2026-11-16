
const express = require('express');
const mongoose = require('mongoose');

const Task = require('../models/Task');
const User = require('../models/User');
const Notification = require('../models/Notification');
const authMiddleware = require('../middleware/auth');

const {
  sendTaskAssignmentEmail,
  sendTaskShareEmail
} = require('../utils/mailer');

const router = express.Router();

router.use(authMiddleware);


// ==========================================
// CÁC HÀM HỖ TRỢ
// ==========================================

function getId(value) {
  if (!value) return '';
  return (value._id || value).toString();
}

// Kiểm tra quyền xem công việc
function canView(task, userId) {
  const id = getId(userId);

  return (
    getId(task.createdBy) === id ||
    getId(task.assignee) === id ||
    (task.assignees || []).some(
      item => getId(item) === id
    ) ||
    (task.sharedWith || []).some(
      item => getId(item.user) === id
    )
  );
}

// Kiểm tra quyền chỉnh sửa công việc
function canEdit(task, userId) {
  const id = getId(userId);

  return (
    getId(task.createdBy) === id ||
    getId(task.assignee) === id ||
    (task.assignees || []).some(
      item => getId(item) === id
    ) ||
    (task.sharedWith || []).some(
      item =>
        getId(item.user) === id &&
        item.permission === 'editor'
    )
  );
}

// Chỉ người tạo mới được quản lý thành viên
function isCreator(task, userId) {
  return getId(task.createdBy) === getId(userId);
}

// Kiểm tra ID công việc
function validTaskId(req, res, next) {
  if (!mongoose.isValidObjectId(req.params.id)) {
    return res.status(400).json({
      success: false,
      message: 'ID cong viec khong hop le'
    });
  }

  next();
}


// ==========================================
// 1. TẠO CÔNG VIỆC VÀ GIAO CHO NHIỀU NGƯỜI
// ==========================================

router.post('/', async (req, res) => {
  try {
    const {
      title,
      description,
      priority,
      status,
      dueDate,
      assigneeEmail,
      assigneeEmails
    } = req.body;

    if (!title || !dueDate) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập tên công việc và hạn hoàn thành'
      });
    }

    // Chuẩn hóa danh sách email
    const emails = [
      ...(Array.isArray(assigneeEmails) ? assigneeEmails : []),
      ...(assigneeEmail ? [assigneeEmail] : [])
    ]
      .filter(Boolean)
      .map(email => email.trim().toLowerCase());

    const uniqueEmails = [...new Set(emails)];

    // Tìm tài khoản đã đăng ký
    const registeredUsers = await User.find({
      email: { $in: uniqueEmails }
    });

    const registeredEmails = new Set(
      registeredUsers.map(user => user.email.toLowerCase())
    );

    // Những email chưa đăng ký
    const externalEmails = uniqueEmails.filter(
      email => !registeredEmails.has(email)
    );

    // Tạo công việc
    const task = await Task.create({
      title,
      description: description || '',
      priority: priority || 'Trung bình',
      status: status || 'Chưa thực hiện',
      createdBy: req.user._id,
      assignee: registeredUsers[0]?._id || null,
      assignees: registeredUsers.map(user => user._id),
      externalAssignees: externalEmails.map(email => ({
        email,
        status: 'sent'
      })),
      startDate: new Date(),
      dueDate
    });

    const inviterName = req.user.name || req.user.email;

    // Tạo thông báo cho tài khoản đã đăng ký
    const notifications = registeredUsers
      .filter(
        user => user._id.toString() !== req.user._id.toString()
      )
      .map(user => ({
        recipient: user._id,
        sender: req.user._id,
        task: task._id,
        title: 'Bạn được giao công việc mới',
        message: `${inviterName} đã giao cho bạn công việc: ${title}`,
        type: 'task_assigned'
      }));

    if (notifications.length > 0) {
      await Notification.insertMany(notifications);
    }

    // Gửi email cho người được giao
    const emailResults = await Promise.allSettled(
      uniqueEmails.map(email =>
        sendTaskAssignmentEmail({
          email,
          taskTitle: title,
          taskDescription: description,
          dueDate,
          inviterName
        })
      )
    );

    const successEmails = [];
    const failedEmails = [];

    emailResults.forEach((result, index) => {
      const email = uniqueEmails[index];

      if (result.status === 'fulfilled') {
        successEmails.push(email);
      } else {
        failedEmails.push(email);

        console.error(
          `Lỗi gửi email đến ${email}:`,
          result.reason?.message || result.reason
        );
      }
    });

    // Cập nhật trạng thái email của người nhận bên ngoài
    for (const email of externalEmails) {
      const emailStatus = failedEmails.includes(email)
        ? 'failed'
        : 'sent';

      await Task.updateOne(
        {
          _id: task._id,
          'externalAssignees.email': email
        },
        {
          $set: {
            'externalAssignees.$.status': emailStatus,
            'externalAssignees.$.sentAt': new Date()
          }
        }
      );
    }

    return res.status(201).json({
      success: true,
      message: failedEmails.length === 0
        ? 'Tạo công việc và gửi email thành công'
        : 'Đã tạo công việc nhưng có email gửi thất bại',
      task,
      successEmails,
      failedEmails
    });

  } catch (error) {
    console.error('Lỗi tạo công việc:', error);

    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 2. LẤY DANH SÁCH CÔNG VIỆC THEO VAI TRÒ
// ==========================================

router.get('/', async (req, res) => {
  try {
    const userId = req.user._id;
    const role = req.query.role || 'all';

    let condition;

    if (role === 'created') {
      condition = {
        createdBy: userId
      };

    } else if (role === 'assigned') {
      condition = {
        $or: [
          { assignee: userId },
          { assignees: userId }
        ]
      };

    } else if (role === 'shared') {
      condition = {
        'sharedWith.user': userId
      };

    } else if (role === 'all') {
      condition = {
        $or: [
          { createdBy: userId },
          { assignee: userId },
          { assignees: userId },
          { 'sharedWith.user': userId }
        ]
      };

    } else {
      return res.status(400).json({
        success: false,
        message: 'Vai tro khong hop le'
      });
    }

    const tasks = await Task.find(condition)
      .populate('createdBy', 'name email')
      .populate('assignee', 'name email')
      .populate('assignees', 'name email')
      .populate('sharedWith.user', 'name email')
      .sort({ createdAt: -1 });

    return res.json({
      success: true,
      tasks
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 3. XEM CHI TIẾT CÔNG VIỆC

// ==========================================
// THỐNG KÊ CÔNG VIỆC
// ==========================================

router.get('/stats', async (req, res) => {
  try {
    const userId = new mongoose.Types.ObjectId(
      req.user._id.toString()
    );

    // Điều kiện lọc công việc theo từng vai trò
    const createdCondition = {
      createdBy: userId
    };

    const assignedCondition = {
      $or: [
        { assignee: userId },
        { assignees: userId }
      ]
    };

    const sharedCondition = {
      'sharedWith.user': userId
    };

    // Tất cả công việc người dùng có quyền truy cập
    const allCondition = {
      $or: [
        { createdBy: userId },
        { assignee: userId },
        { assignees: userId },
        { 'sharedWith.user': userId }
      ]
    };
    // Thời gian hiện tại và mốc 3 ngày tới
    const now = new Date();

    const threeDaysLater = new Date();
    threeDaysLater.setDate(threeDaysLater.getDate() + 3);

    // Công việc sắp đến hạn
    const dueSoonCondition = {
      ...allCondition,
      dueDate: {
        $gte: now,
        $lte: threeDaysLater
      },
      status: { $ne: 'Đã hoàn thành' }
    };

    // Công việc đã quá hạn
    const overdueCondition = {
      ...allCondition,
      dueDate: { $lt: now },
      status: { $ne: 'Đã hoàn thành' }
    };

    // Lấy số lượng công việc theo trạng thái
    const statusStats = await Task.aggregate([
      { $match: allCondition },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 }
        }
      }
    ]);

    // Tổng số công việc theo vai trò
    const [
      totalTasks,
      createdTasks,
      assignedTasks,
      sharedTasks,
      dueSoonTasks,
      overdueTasks,
      dueSoonList,
      overdueList
    ] = await Promise.all([
      Task.countDocuments(allCondition),
      Task.countDocuments(createdCondition),
      Task.countDocuments(assignedCondition),
      Task.countDocuments(sharedCondition),
      Task.countDocuments(dueSoonCondition),
      Task.countDocuments(overdueCondition),

      Task.find(dueSoonCondition)
        .select('title status dueDate priority')
        .sort({ dueDate: 1 })
        .lean(),

      Task.find(overdueCondition)
        .select('title status dueDate priority')
        .sort({ dueDate: 1 })
        .lean()
    ]);

    // Chuyển kết quả thống kê thành đối tượng dễ sử dụng
    const byStatus = {
      'Chưa thực hiện': 0,
      'Đang thực hiện': 0,
      'Đã hoàn thành': 0
    };

    statusStats.forEach(item => {
      byStatus[item._id] = item.count;
    });

    return res.json({
      success: true,
      stats: {
        totalTasks,
        createdTasks,
        assignedTasks,
        sharedTasks,
        dueSoonTasks,
        overdueTasks,
        dueSoonList,
        overdueList,
        byStatus
      }
    });

  } catch (error) {
    console.error('Lỗi thống kê công việc:', error);

    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ==========================================

router.get('/:id', validTaskId, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id)
      .populate('createdBy', 'name email')
      .populate('assignee', 'name email')
      .populate('assignees', 'name email')
      .populate('sharedWith.user', 'name email');

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    if (!canView(task, req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Ban khong co quyen xem cong viec'
      });
    }

    return res.json({
      success: true,
      task
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 4. CẬP NHẬT CÔNG VIỆC
// ==========================================

router.patch('/:id', validTaskId, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    if (!canEdit(task, req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Ban khong co quyen chinh sua'
      });
    }

    const allowedFields = [
      'title',
      'description',
      'status',
      'priority',
      'dueDate'
    ];

    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) {
        task[field] = req.body[field];
      }
    });

    await task.save();

    // Xác định người nhận thông báo
    const recipients = [
      ...new Set([
        getId(task.createdBy),
        getId(task.assignee),
        ...(task.assignees || []).map(item => getId(item)),
        ...(task.sharedWith || []).map(item => getId(item.user))
      ])
    ].filter(
      id => id && id !== req.user._id.toString()
    );

    const isCompleted = task.status === 'Hoàn thành';

    const notificationTitle = isCompleted
      ? 'Công việc đã hoàn thành'
      : 'Công việc vừa được cập nhật';

    const notificationType = isCompleted
      ? 'task_completed'
      : 'task_updated';

    if (recipients.length > 0) {
      await Notification.insertMany(
        recipients.map(recipient => ({
          recipient,
          sender: req.user._id,
          task: task._id,
          title: notificationTitle,
          message: isCompleted
            ? `Công việc "${task.title}" đã được hoàn thành`
            : `Công việc "${task.title}" vừa được cập nhật`,
          type: notificationType
        }))
      );
    }

    return res.json({
      success: true,
      message: 'Cap nhat cong viec thanh cong',
      task
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 5. THAY ĐỔI NGƯỜI PHỤ TRÁCH CHÍNH
// ==========================================

router.patch('/:id/assignee', validTaskId, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    if (!isCreator(task, req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Chi nguoi tao moi duoc giao lai cong viec'
      });
    }

    const { email } = req.body;

    const oldAssigneeIds = (task.assignees || []).map(
      item => getId(item)
    );

    if (!email) {
      task.assignee = null;
      task.assignees = [];

    } else {
      const user = await User.findOne({
        email: email.trim().toLowerCase()
      });

      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'Khong tim thay tai khoan'
        });
      }

      if (user._id.toString() === task.createdBy.toString()) {
        return res.status(400).json({
          success: false,
          message: 'Nguoi tao khong the tu giao viec cho chinh minh'
        });
      }

      task.assignee = user._id;
      task.assignees = [user._id];
    }

    await task.save();

    const newAssigneeIds = (task.assignees || []).map(
      item => getId(item)
    );

    const newlyAssignedIds = newAssigneeIds.filter(
      id =>
        !oldAssigneeIds.includes(id) &&
        id !== req.user._id.toString()
    );

    const inviterName = req.user.name || req.user.email;

    const newlyAssignedUsers = await User.find({
      _id: { $in: newlyAssignedIds }
    });

    if (newlyAssignedUsers.length > 0) {
      await Notification.insertMany(
        newlyAssignedUsers.map(user => ({
          recipient: user._id,
          sender: req.user._id,
          task: task._id,
          title: 'Bạn được giao công việc',
          message: `Bạn được giao phụ trách công việc: ${task.title}`,
          type: 'task_assigned'
        }))
      );
    }

    const emailResults = await Promise.allSettled(
      newlyAssignedUsers.map(user =>
        sendTaskAssignmentEmail({
          email: user.email,
          taskTitle: task.title,
          taskDescription: task.description,
          dueDate: task.dueDate,
          inviterName
        })
      )
    );

    const successEmails = [];
    const failedEmails = [];

    emailResults.forEach((result, index) => {
      const recipientEmail = newlyAssignedUsers[index].email;

      if (result.status === 'fulfilled') {
        successEmails.push(recipientEmail);
      } else {
        failedEmails.push(recipientEmail);

        console.error(
          `Lỗi gửi email đến ${recipientEmail}:`,
          result.reason?.message || result.reason
        );
      }
    });

    return res.json({
      success: true,
      message: failedEmails.length === 0
        ? 'Thay doi nguoi phu trach thanh cong'
        : 'Da giao lai cong viec nhung gui email that bai',
      successEmails,
      failedEmails,
      task
    });

  } catch (error) {
    console.error('Lỗi thay đổi người phụ trách:', error);

    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 6. XEM DANH SÁCH NGƯỜI ĐƯỢC GIAO
//    VÀ NGƯỜI ĐƯỢC CHIA SẺ
// ==========================================

router.get('/:id/shares', validTaskId, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id)
      .populate('createdBy', 'name email')
      .populate('assignee', 'name email')
      .populate('assignees', 'name email')
      .populate('sharedWith.user', 'name email');

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    if (!canView(task, req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Ban khong co quyen xem cong viec'
      });
    }

    return res.json({
      success: true,

      // Người tạo
      createdBy: task.createdBy,

      // Người được giao
      assignee: task.assignee,
      assignees: task.assignees || [],
      externalAssignees: task.externalAssignees || [],

      // Người được chia sẻ
      sharedWith: task.sharedWith || [],
      externalSharedWith: task.externalSharedWith || []
    });

  } catch (error) {
    console.error('Lỗi lấy danh sách thành viên:', error);

    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 7. CHIA SẺ CÔNG VIỆC CHO MỘT TÀI KHOẢN
// ==========================================

router.post('/:id/shares', validTaskId, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc'
      });
    }

    if (!isCreator(task, req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo mới được chia sẻ công việc'
      });
    }

    const email = req.body.email?.trim().toLowerCase();
    const permission = req.body.permission;

    if (
      !email ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !['viewer', 'editor'].includes(permission)
    ) {
      return res.status(400).json({
        success: false,
        message: 'Email hoặc quyền chia sẻ không hợp lệ'
      });
    }

    const inviter = await User.findById(task.createdBy)
      .select('name email');

    const user = await User.findOne({ email });

    // Khởi tạo danh sách nếu chưa có
    if (!task.sharedWith) {
      task.sharedWith = [];
    }

    if (!task.externalSharedWith) {
      task.externalSharedWith = [];
    }

    if (user) {
      const userId = user._id.toString();

      // Không cho chia sẻ lại cho người tạo hoặc người phụ trách
      if (
        userId === task.createdBy.toString() ||
        (task.assignee && userId === task.assignee.toString()) ||
        (task.assignees || []).some(
          item => getId(item) === userId
        )
      ) {
        return res.status(400).json({
          success: false,
          message: 'Tài khoản này đã là người tạo hoặc người phụ trách'
        });
      }

      const existing = task.sharedWith.find(
        item => getId(item.user) === userId
      );

      if (existing) {
        return res.status(409).json({
          success: false,
          message: 'Tài khoản đã được chia sẻ'
        });
      }

      task.sharedWith.push({
        user: user._id,
        permission
      });

    } else {
      // Email chưa đăng ký tài khoản
      const existing = task.externalSharedWith.find(
        item => item.email.toLowerCase() === email
      );

      if (existing) {
        return res.status(409).json({
          success: false,
          message: 'Email này đã được mời chia sẻ'
        });
      }

      task.externalSharedWith.push({
        email,
        permission,
        status: 'pending'
      });
    }

    await task.save();

    // Tạo thông báo cho người dùng đã đăng ký
    if (user) {
      await Notification.create({
        recipient: user._id,
        sender: req.user._id,
        task: task._id,
        title: 'Bạn được chia sẻ công việc',
        message: `${inviter?.name || inviter?.email || 'Một người dùng'} đã chia sẻ công việc: ${task.title}`,
        type: 'task_shared'
      });
    }

    let emailSent = false;
    let emailError = null;

    try {
      await sendTaskShareEmail({
        email,
        taskTitle: task.title,
        taskDescription: task.description,
        dueDate: task.dueDate,
        inviterName: inviter?.name || inviter?.email || 'Task Manager',
        permission
      });

      emailSent = true;

    } catch (mailError) {
      emailError = mailError.message;

      console.error(
        'Lỗi gửi email chia sẻ:',
        mailError.message
      );
    }

    // Cập nhật trạng thái email của người chưa đăng ký
    if (!user) {
      const externalShare = task.externalSharedWith.find(
        item => item.email === email
      );

      if (externalShare) {
        externalShare.status = emailSent ? 'sent' : 'failed';
        externalShare.sentAt = emailSent ? new Date() : null;

        await task.save();
      }
    }

    return res.status(201).json({
      success: true,
      message: emailSent
        ? 'Chia sẻ công việc và gửi email thành công'
        : 'Đã lưu chia sẻ nhưng gửi email thất bại',
      emailSent,
      emailError,
      recipientType: user ? 'registered' : 'external',
      task
    });

  } catch (error) {
    console.error('Lỗi chia sẻ công việc:', error);

    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 8. THAY ĐỔI QUYỀN VIEWER / EDITOR
// ==========================================

router.patch('/:id/shares/:userId', validTaskId, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    if (!isCreator(task, req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Chi nguoi tao moi duoc thay doi quyen'
      });
    }

    const { permission } = req.body;

    if (!['viewer', 'editor'].includes(permission)) {
      return res.status(400).json({
        success: false,
        message: 'Quyen khong hop le'
      });
    }

    const member = (task.sharedWith || []).find(
      item => getId(item.user) === req.params.userId
    );

    if (!member) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay nguoi duoc chia se'
      });
    }

    member.permission = permission;

    await task.save();

    return res.json({
      success: true,
      message: 'Thay doi quyen thanh cong',
      task
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


// ==========================================
// 9. THU HỒI QUYỀN CHIA SẺ
// ==========================================

router.delete('/:id/shares/:userId', validTaskId, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay cong viec'
      });
    }

    if (!isCreator(task, req.user._id)) {
      return res.status(403).json({
        success: false,
        message: 'Chi nguoi tao moi duoc thu hoi quyen'
      });
    }

    const oldLength = (task.sharedWith || []).length;

    task.sharedWith = (task.sharedWith || []).filter(
      item => getId(item.user) !== req.params.userId
    );

    if (task.sharedWith.length === oldLength) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay nguoi duoc chia se'
      });
    }

    await task.save();

    return res.json({
      success: true,
      message: 'Thu hoi quyen thanh cong'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});




module.exports = router;
