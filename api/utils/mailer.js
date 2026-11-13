
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_APP_PASSWORD
  }
});

// Gửi email khi giao công việc
async function sendTaskAssignmentEmail({
  email,
  taskTitle,
  taskDescription,
  dueDate,
  inviterName
}) {
  const deadline = dueDate
    ? new Date(dueDate).toLocaleDateString('vi-VN')
    : 'Chưa đặt';

  await transporter.sendMail({
    from: `"Task Manager" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: `Bạn được giao công việc: ${taskTitle}`,
    text: `
Xin chào!

${inviterName} đã giao cho bạn công việc:

Tên công việc: ${taskTitle}
Mô tả: ${taskDescription || 'Không có mô tả'}
Hạn hoàn thành: ${deadline}

Vui lòng đăng nhập Task Manager để theo dõi công việc.

Trân trọng,
Task Manager
`
  });
}

// Gửi email khi công việc được chia sẻ
async function sendTaskShareEmail({
  email,
  taskTitle,
  taskDescription,
  dueDate,
  inviterName,
  permission
}) {
  const deadline = dueDate
    ? new Date(dueDate).toLocaleDateString('vi-VN')
    : 'Chưa đặt';

  const permissionText = permission === 'editor'
    ? 'Bạn có quyền chỉnh sửa công việc.'
    : 'Bạn chỉ có quyền xem công việc.';

  await transporter.sendMail({
    from: `"Task Manager" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: `Bạn được chia sẻ công việc: ${taskTitle}`,
    text: `
Xin chào!

${inviterName} đã chia sẻ một công việc với bạn.

Tên công việc: ${taskTitle}
Mô tả: ${taskDescription || 'Không có mô tả'}
Hạn hoàn thành: ${deadline}

Quyền được cấp: ${permissionText}

Vui lòng đăng nhập Task Manager để xem công việc được chia sẻ.

Trân trọng,
Task Manager
`
  });
}

module.exports = {
  sendTaskAssignmentEmail,
  sendTaskShareEmail
};
