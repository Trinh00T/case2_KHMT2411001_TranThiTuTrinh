
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color statsPrimaryBlue = Color(0xFF2475ED);
const Color statsDarkBlue = Color(0xFF26344D);

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _stats;

  static const String baseUrl = 'http://10.0.2.2:3000';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'Bạn chưa đăng nhập. Vui lòng đăng nhập lại.',
        );
      }

      final response = await http
          .get(
        Uri.parse('$baseUrl/api/tasks/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
          .timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final statsData =
        Map<String, dynamic>.from(result['stats']);

        if (!mounted) return;

        setState(() {
          _stats = statsData;
          _isLoading = false;
        });
      } else {
        throw Exception(
          result['message'] ??
              'Không thể tải dữ liệu thống kê.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  List<Map<String, dynamic>> _getTaskList(String key) {
    final data = _stats?[key];

    if (data is! List) return [];

    return data
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Chưa có ngày đến hạn';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return 'Ngày không hợp lệ';
    }

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Thống kê công việc',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: statsPrimaryBlue,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: statsPrimaryBlue,
        ),
      )
          : _errorMessage != null
          ? _buildError()
          : _buildStatistics(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 55,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Đã xảy ra lỗi.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final total = _number(_stats?['totalTasks']);
    final created = _number(_stats?['createdTasks']);
    final assigned = _number(_stats?['assignedTasks']);
    final shared = _number(_stats?['sharedTasks']);

    final dueSoonList = _getTaskList('dueSoonList');
    final overdueList = _getTaskList('overdueList');

    final dueSoonCount =
    _number(_stats?['dueSoonTasks']);
    final overdueCount =
    _number(_stats?['overdueTasks']);

    final byStatus = Map<String, dynamic>.from(
      _stats?['byStatus'] ?? {},
    );

    final notStarted =
    _number(byStatus['Chưa thực hiện']);
    final inProgress =
    _number(byStatus['Đang thực hiện']);
    final completed =
    _number(byStatus['Đã hoàn thành']);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTotalCard(total),

          const SizedBox(height: 18),

          const Text(
            'Tổng quan công việc',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statsDarkBlue,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Công việc đã tạo',
                  created,
                  Icons.create_new_folder_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Công việc được giao',
                  assigned,
                  Icons.assignment_ind_outlined,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildInfoCard(
            'Công việc được chia sẻ',
            shared,
            Icons.share_outlined,
            Colors.purple,
          ),

          const SizedBox(height: 24),

          const Text(
            'Thống kê theo trạng thái',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statsDarkBlue,
            ),
          ),

          const SizedBox(height: 14),

          _buildStatusCard(
            title: 'Chưa thực hiện',
            count: notStarted,
            total: total,
            color: Colors.orange,
            icon: Icons.pending_actions,
          ),

          const SizedBox(height: 12),

          _buildStatusCard(
            title: 'Đang thực hiện',
            count: inProgress,
            total: total,
            color: statsPrimaryBlue,
            icon: Icons.autorenew,
          ),

          const SizedBox(height: 12),

          _buildStatusCard(
            title: 'Đã hoàn thành',
            count: completed,
            total: total,
            color: Colors.green,
            icon: Icons.check_circle_outline,
          ),

          const SizedBox(height: 24),

          const Text(
            'Theo dõi thời hạn',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statsDarkBlue,
            ),
          ),

          const SizedBox(height: 14),

          _buildTaskListSection(
            title: 'Công việc sắp đến hạn',
            count: dueSoonCount,
            tasks: dueSoonList,
            color: Colors.orange,
            icon: Icons.access_time,
          ),

          const SizedBox(height: 16),

          _buildTaskListSection(
            title: 'Công việc quá hạn',
            count: overdueCount,
            tasks: overdueList,
            color: Colors.red,
            icon: Icons.warning_amber_rounded,
          ),

          const SizedBox(height: 20),

          const Center(
            child: Text(
              'Kéo xuống để cập nhật dữ liệu',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(int total) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            statsPrimaryBlue,
            statsDarkBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.analytics_outlined,
            color: Colors.white,
            size: 38,
          ),

          const SizedBox(height: 10),

          const Text(
            'TỔNG SỐ CÔNG VIỆC',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Text(
            'Công việc trong hệ thống',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      String title,
      int count,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: statsDarkBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required int count,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final double progress =
    total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    final percentage =
    (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: statsDarkBlue,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            '$percentage% tổng số công việc',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskListSection({
    required String title,
    required int count,
    required List<Map<String, dynamic>> tasks,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statsDarkBlue,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (tasks.isEmpty)
            const Text(
              'Không có công việc.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...tasks.map((task) {
              final taskTitle =
              (task['title'] ?? 'Không có tiêu đề').toString();

              final status =
              (task['status'] ?? '').toString();

              final priority =
              (task['priority'] ?? '').toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statsDarkBlue,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Hạn: ${_formatDate(task['dueDate'])}',
                      style: const TextStyle(fontSize: 13),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Trạng thái: $status',
                      style: const TextStyle(fontSize: 13),
                    ),

                    Text(
                      'Ưu tiên: ${priority.isEmpty ? 'Chưa xác định' : priority}',
                      style: const TextStyle(fontSize: 13),
                    ),

                    const Divider(height: 18),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
