const express = require('express');
const mongoose = require('mongoose');

const Task = require('../models/Task');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const {
  sendTaskAssignmentEmail,
  sendTaskShareEmail
} = require('../utils/mailer');
const router = express.Router();

router.use(authMiddleware);


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
  return task.createdBy.toString() === userId.toString();
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


// 1. Tạo công việc và giao cho mot hoac nhieu nguoi
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
        message: 'Vui long nhap ten cong viec va han hoan thanh'
      });
    }

    // Ho tro ca email cu va danh sach email moi
    const emails = [
      ...(Array.isArray(assigneeEmails) ? assigneeEmails : []),
      ...(assigneeEmail ? [assigneeEmail] : [])
    ]
      .filter(Boolean)
      .map(email => email.trim().toLowerCase());

    const uniqueEmails = [...new Set(emails)];

    const registeredUsers = await User.find({
      email: { $in: uniqueEmails }
    });

    const registeredEmails = new Set(
      registeredUsers.map(user => user.email.toLowerCase())
    );

    const externalEmails = uniqueEmails.filter(
      email => !registeredEmails.has(email)
    );

    const task = await Task.create({
      title,
      description: description || '',
      priority: priority || 'Trung bình',
      status: status || 'Chưa thực hiện',
      createdBy: req.user._id,
      assignee: registeredUsers.length > 0
        ? registeredUsers[0]._id
        : null,
      assignees: registeredUsers.map(user => user._id),
      externalAssignees: externalEmails.map(email => ({
        email,
        status: 'sent'
      })),
      startDate: new Date(),
      dueDate
    });

    const inviterName = req.user.name || req.user.email;

    const emailResults = await Promise.allSettled(
      externalEmails.map(email =>
        sendTaskAssignmentEmail({
          email,
          taskTitle: title,
          taskDescription: description,
          dueDate,
          inviterName
        })
      )
    );

    const failedEmails = [];

    emailResults.forEach((result, index) => {
      if (result.status === 'rejected') {
        failedEmails.push(externalEmails[index]);
      }
    });

    if (failedEmails.length > 0) {
      await Task.updateOne(
        { _id: task._id },
        {
          $set: {
            'externalAssignees.$[item].status': 'failed'
          }
        },
        {
          arrayFilters: [
            { 'item.email': { $in: failedEmails } }
          ]
        }
      );
    }

    return res.status(201).json({
      success: true,
      message: 'Tao cong viec thanh cong',
      task,
      failedEmails
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// 2. Lấy danh sách công việc theo vai trò
router.get('/', async (req, res) => {
  try {
    const userId = req.user._id;
    const role = req.query.role || 'all';

    let condition;

    if (role === 'created') {
      condition = { createdBy: userId };
    } else if (role === 'assigned') {
      condition = {
        $or: [
          { assignee: userId },
          { assignees: userId }
        ]
      };
    } else if (role === 'shared') {
      condition = { 'sharedWith.user': userId };
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

// 3. Xem chi tiết công việc
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

// 4. Cập nhật công việc
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

// 5. Thay đổi người phụ trách chính
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

    return res.json({
      success: true,
      message: 'Thay doi nguoi phu trach thanh cong',
      task
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// 6. Xem danh sach nguoi duoc giao va nguoi duoc chia se
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
        message: 'Ban khong co quyen xem'
      });
    }

    return res.json({
      success: true,
      createdBy: task.createdBy,
      assignee: task.assignee,
      assignees: task.assignees,
      externalAssignees: task.externalAssignees,
      sharedWith: task.sharedWith
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});
// 7. Chia se cong viec cho mot tai khoan
router.post('/:id/shares', validTaskId, async (req, res) => {
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
        message: 'Chi nguoi tao moi duoc chia se cong viec'
      });
    }

    const { email, permission } = req.body;

    if (!email || !['viewer', 'editor'].includes(permission)) {
      return res.status(400).json({
        success: false,
        message: 'Email hoac quyen chia se khong hop le'
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase()
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Khong tim thay tai khoan'
      });
    }

    const userId = user._id.toString();

 if (
   userId === task.createdBy.toString() ||
   (task.assignee && userId === task.assignee.toString()) ||
   (task.assignees || []).some(
     item => item.toString() === userId
   )
 ) {
   return res.status(400).json({
     success: false,
     message: 'Tai khoan nay da la nguoi tao hoac nguoi phu trach'
   });
 }

 const existing = task.sharedWith.find(
   item => item.user.toString() === userId
 );


    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'Tai khoan da duoc chia se'
      });
    }

    task.sharedWith.push({
      user: user._id,
      permission
    });


await task.save();

// Lay thong tin nguoi tao cong viec
const inviter = await User.findById(task.createdBy).select('name email');

let emailSent = false;
let emailError = null;

try {
  await sendTaskShareEmail({
    email: user.email,
    taskTitle: task.title,
    taskDescription: task.description,
    dueDate: task.dueDate,
    inviterName: inviter?.name || inviter?.email || 'Task Manager',
    permission
  });

  emailSent = true;
} catch (mailError) {
  emailError = mailError.message;
  console.error('Loi gui email chia se:', mailError.message);
}

return res.status(201).json({
  success: true,
  message: emailSent
    ? 'Chia se cong viec va gui email thong bao thanh cong'
    : 'Da chia se cong viec nhung gui email thong bao that bai',
  emailSent,
  emailError,
  task
});

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// 8. Thay đổi quyền Viewer / Editor
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

    const member = task.sharedWith.find(
      item => item.user.toString() === req.params.userId
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

// 9. Thu hoi quyen chia se
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

    const oldLength = task.sharedWith.length;

    task.sharedWith = task.sharedWith.filter(
      item => item.user.toString() !== req.params.userId
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
