
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_APP_PASSWORD
  }
});

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

Đây là email thông báo công việc từ Task Manager.
`,
  });
}

module.exports = { sendTaskAssignmentEmail };
