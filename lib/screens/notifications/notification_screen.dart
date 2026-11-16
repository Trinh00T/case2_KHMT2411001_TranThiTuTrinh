import 'package:flutter/material.dart';

const Color _primaryBlue = Color(0xFF2475ED);
const Color _darkBlue = Color(0xFF26344D);
const Color _background = Color(0xFFF5F7FB);

class NotificationItem {
  final String title;
  final String message;
  final String time;
  final String type;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.isRead = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _selectedTab = 0;

  final List<NotificationItem> _notifications = [
    NotificationItem(
      title: 'Bạn được giao công việc mới',
      message: 'Nguyễn Văn An đã giao cho bạn công việc "Thiết kế giao diện".',
      time: '5 phút trước',
      type: 'assign',
    ),
    NotificationItem(
      title: 'Bạn được mời tham gia công việc',
      message: 'Trần Minh đã mời bạn tham gia công việc "Xây dựng ứng dụng".',
      time: '30 phút trước',
      type: 'share',
    ),
    NotificationItem(
      title: 'Công việc sắp đến hạn',
      message: 'Công việc "Hoàn thành báo cáo" sẽ hết hạn sau 24 giờ.',
      time: '2 giờ trước',
      type: 'reminder',
    ),
    NotificationItem(
      title: 'Công việc đã hoàn thành',
      message: 'Công việc "Phân tích yêu cầu" đã được đánh dấu hoàn thành.',
      time: 'Hôm qua',
      type: 'complete',
      isRead: true,
    ),
    NotificationItem(
      title: 'Thông tin công việc đã thay đổi',
      message: 'Hạn hoàn thành công việc "Kiểm thử ứng dụng" đã được cập nhật.',
      time: 'Hôm qua',
      type: 'update',
      isRead: true,
    ),
  ];

  int get _unreadCount => _notifications.where((item) => !item.isRead).length;

  List<NotificationItem> get _displayedNotifications {
    if (_selectedTab == 1) {
      return _notifications.where((item) => !item.isRead).toList();
    }
    return _notifications;
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'assign':
        return Icons.assignment_add;
      case 'share':
        return Icons.group_add_outlined;
      case 'reminder':
        return Icons.alarm;
      case 'complete':
        return Icons.task_alt;
      default:
        return Icons.edit_notifications_outlined;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'assign':
        return Colors.blue;
      case 'share':
        return Colors.purple;
      case 'reminder':
        return Colors.orange;
      case 'complete':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (final item in _notifications) {
        item.isRead = true;
      }
    });
  }

  void _openNotification(NotificationItem item) {
    setState(() {
      item.isRead = true;
    });

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(_getIcon(item.type), color: _getColor(item.type)),
            const SizedBox(width: 10),
            Expanded(child: Text(item.title)),
          ],
        ),
        content: Text(item.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _displayedNotifications;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: _unreadCount == 0 ? null : _markAllAsRead,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: const BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cập nhật hoạt động',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Bạn có $_unreadCount thông báo chưa đọc',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Row(
              children: [
                _buildTab('Tất cả', 0, _notifications.length),
                const SizedBox(width: 10),
                _buildTab('Chưa đọc', 1, _unreadCount),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(items[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, int count) {
    final selected = _selectedTab == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _primaryBlue : const Color(0xFFE1E6EF),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : _darkBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : _primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final color = _getColor(item.type);

    return Card(
      color: item.isRead ? Colors.white : const Color(0xFFF0F5FF),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 11),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: item.isRead
              ? const Color(0xFFE8ECF3)
              : const Color(0xFFD5E4FF),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _openNotification(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(_getIcon(item.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: _darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.message,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      item.time,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 5, left: 7),
                  decoration: const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 65, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Không có thông báo nào',
            style: TextStyle(color: _darkBlue, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 5),
          Text(
            'Các thông báo mới sẽ xuất hiện tại đây.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
