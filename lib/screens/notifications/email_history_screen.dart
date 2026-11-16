import 'package:flutter/material.dart';

const Color _primaryBlue = Color(0xFF2475ED);
const Color _darkBlue = Color(0xFF26344D);
const Color _background = Color(0xFFF5F7FB);

class EmailRecord {
  final String title;
  final String recipient;
  final String time;
  final String description;
  final bool success;

  const EmailRecord({
    required this.title,
    required this.recipient,
    required this.time,
    required this.description,
    required this.success,
  });
}

class EmailHistoryScreen extends StatefulWidget {
  const EmailHistoryScreen({super.key});

  @override
  State<EmailHistoryScreen> createState() => _EmailHistoryScreenState();
}

class _EmailHistoryScreenState extends State<EmailHistoryScreen> {
  int _selectedFilter = 0;

  final List<EmailRecord> _records = const [
    EmailRecord(
      title: 'Thông báo giao công việc mới',
      recipient: 'nguyenvana@gmail.com',
      time: '14/11/2026 - 08:30',
      description:
          'Email thông báo bạn được giao công việc Thiết kế giao diện.',
      success: true,
    ),
    EmailRecord(
      title: 'Lời mời tham gia công việc',
      recipient: 'tranminh@gmail.com',
      time: '14/11/2026 - 09:15',
      description: 'Email mời tham gia công việc Xây dựng ứng dụng.',
      success: true,
    ),
    EmailRecord(
      title: 'Nhắc nhở công việc sắp đến hạn',
      recipient: 'lethib@gmail.com',
      time: '14/11/2026 - 10:00',
      description: 'Email nhắc nhở công việc Hoàn thành báo cáo.',
      success: false,
    ),
    EmailRecord(
      title: 'Thông báo hoàn thành công việc',
      recipient: 'nguyenvana@gmail.com',
      time: '13/11/2026 - 16:45',
      description: 'Email xác nhận công việc đã hoàn thành.',
      success: true,
    ),
    EmailRecord(
      title: 'Thông báo cập nhật hạn công việc',
      recipient: 'phamminhc@gmail.com',
      time: '13/11/2026 - 17:20',
      description: 'Email thông báo thời hạn công việc đã thay đổi.',
      success: false,
    ),
  ];

  List<EmailRecord> get _filteredRecords {
    if (_selectedFilter == 1) {
      return _records.where((item) => item.success).toList();
    }

    if (_selectedFilter == 2) {
      return _records.where((item) => !item.success).toList();
    }

    return _records;
  }

  int get _successCount => _records.where((item) => item.success).length;

  int get _failedCount => _records.where((item) => !item.success).length;

  void _showEmailDetail(EmailRecord record) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Chi tiết email',
            style: TextStyle(color: _darkBlue, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Tiêu đề', record.title),
              _detailRow('Người nhận', record.recipient),
              _detailRow('Thời gian', record.time),
              _detailRow('Nội dung', record.description),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    record.success ? Icons.check_circle : Icons.error,
                    color: record.success ? Colors.green : Colors.red,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    record.success ? 'Gửi thành công' : 'Gửi thất bại',
                    style: TextStyle(
                      color: record.success ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _darkBlue, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Lịch sử email',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummary(
                    'Tổng email',
                    _records.length,
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummary(
                    'Thành công',
                    _successCount,
                    Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummary(
                    'Thất bại',
                    _failedCount,
                    Icons.error_outline,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                _buildFilter('Tất cả', 0),
                const SizedBox(width: 8),
                _buildFilter('Thành công', 1),
                const SizedBox(width: 8),
                _buildFilter('Thất bại', 2),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      'Không có lịch sử email',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _buildEmailCard(records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 23),
          const SizedBox(height: 7),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter(String title, int index) {
    final selected = _selectedFilter == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? _primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _primaryBlue : const Color(0xFFE1E6EF),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : _darkBlue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCard(EmailRecord record) {
    final statusColor = record.success ? Colors.green : Colors.red;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 11),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFE8ECF3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showEmailDetail(record),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: _primaryBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      record.title,
                      style: const TextStyle(
                        color: _darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Người nhận: ${record.recipient}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                record.time,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    record.success ? Icons.check_circle : Icons.error,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    record.success ? 'Gửi thành công' : 'Gửi thất bại',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Chi tiết',
                    style: TextStyle(
                      color: _primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: _primaryBlue,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
