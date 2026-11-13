

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color taskPrimaryBlue = Color(0xFF2475ED);
const Color taskDarkBlue = Color(0xFF26344D);

class TaskItem {
  String? id;
  String title;
  String description;
  String status;
  String priority;
  DateTime startDate;
  DateTime createdDate;
  DateTime dueDate;
  String assignee;
  List<String> assignees;
  String? primaryAssignee;
  List<SharedMember> sharedWith;

  TaskItem({
    this.id,
    required this.title,
    this.description = '',
    this.status = 'Chưa thực hiện',
    this.priority = 'Trung bình',
    required this.startDate,
    DateTime? createdDate,
    required this.dueDate,
    this.assignee = 'Tôi',
    this.assignees = const [],
    this.primaryAssignee,
    List<SharedMember>? sharedWith,

  })  : createdDate = createdDate ?? DateTime.now(),
        sharedWith = sharedWith ?? [];

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    String getUserName(dynamic user) {
      if (user is Map) {
        return (user['name'] ?? user['email'] ?? '').toString();
      }
      return '';
    }

    final assigneeData = json['assignee'];

    final assigneesData = json['assignees'] is List
        ? json['assignees'] as List
        : [];

    final sharedData = json['sharedWith'] is List
        ? json['sharedWith'] as List
        : [];

    return TaskItem(
      id: json['_id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Chưa thực hiện',
      priority: json['priority']?.toString() ?? 'Trung bình',
      startDate: DateTime.tryParse(
        json['startDate']?.toString() ?? '',
      ) ??
          DateTime.now(),
      createdDate: DateTime.tryParse(
        (json['createdAt'] ?? json['createdDate'])?.toString() ?? '',
      ) ??
          DateTime.now(),
      dueDate: DateTime.tryParse(
        json['dueDate']?.toString() ?? '',
      ) ??
          DateTime.now(),
      assignee: getUserName(assigneeData).isEmpty
          ? 'Tôi'
          : getUserName(assigneeData),
      assignees: assigneesData
          .map((user) => getUserName(user))
          .where((name) => name.isNotEmpty)
          .toList(),
      primaryAssignee: getUserName(assigneeData),
      sharedWith: sharedData.map((item) {
        final user = item['user'];
        final email = user is Map
            ? (user['email'] ?? '').toString()
            : '';

        final permission =
        (item['permission'] ?? 'viewer').toString();

        return SharedMember(
          userId: user is Map ? user['_id']?.toString() : null,
          email: email,
          permission: permission.toLowerCase() == 'editor'
              ? 'Editor'
              : 'Viewer',
        );
      }).where((member) => member.email.isNotEmpty).toList(),
    );
  }
}


class SharedMember {
  String? userId;
  String email;
  String permission;

  SharedMember({
    this.userId,
    required this.email,
    this.permission = 'Viewer',
  });
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {

  static const String baseUrl = 'http://10.0.2.2:3000';

  bool _isLoadingTasks = false;

  Future<void> _loadTasks() async {
    setState(() {
      _isLoadingTasks = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Không tìm thấy token đăng nhập. Vui lòng đăng nhập lại.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> taskData = data['tasks'] ?? [];

        final loadedTasks = taskData
            .map((item) => TaskItem.fromJson(
          item as Map<String, dynamic>,
        ))
            .toList();

        if (!mounted) return;

        setState(() {
          _tasks
            ..clear()
            ..addAll(loadedTasks);
        });
      } else {
        throw Exception(
          'Không tải được công việc (${response.statusCode}): ${response.body}',
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải công việc: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
        });
      }
    }
  }


  final TextEditingController _searchController = TextEditingController();

  Future<TaskItem> _createTaskOnServer(TaskItem task) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy token đăng nhập. Vui lòng đăng nhập lại.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': task.title,
        'description': task.description,
        'priority': task.priority,
        'status': task.status,
        'dueDate': task.dueDate.toIso8601String(),
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 && data['success'] == true) {
      return TaskItem.fromJson(
        data['task'] as Map<String, dynamic>,
      );
    }

    throw Exception(
      data['message']?.toString() ??
          'Không thể lưu công việc (${response.statusCode})',
    );
  }

  Future<Map<String, dynamic>> _shareTaskOnServer(
      TaskItem task,
      String email,
      String permission,
      ) async {
    if (task.id == null || task.id!.isEmpty) {
      throw Exception('Công việc chưa có ID trên máy chủ!');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại!');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks/${task.id}/shares'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'email': email,
        'permission': permission.toLowerCase(),
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 && data['success'] == true) {
      return data as Map<String, dynamic>;
    }

    throw Exception(
      data['message']?.toString() ??
          'Không thể chia sẻ công việc (${response.statusCode})',
    );
  }

  Future<List<SharedMember>> _loadSharedMembers(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Vui lòng đăng nhập lại!');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/tasks/$taskId/shares'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(
        data['message']?.toString() ??
            'Không tải được danh sách chia sẻ',
      );
    }

    final sharedData = data['sharedWith'] is List
        ? data['sharedWith'] as List
        : [];

    return sharedData.map<SharedMember>((item) {
      final user = item['user'];
      final email = user is Map
          ? (user['email'] ?? '').toString()
          : '';

      final permission = (item['permission'] ?? 'viewer').toString();

      return SharedMember(
        userId: user is Map ? user['_id']?.toString() : null,
        email: email,
        permission: permission.toLowerCase() == 'editor'
            ? 'Editor'
            : 'Viewer',
      );
    }).where((member) => member.email.isNotEmpty).toList();
  }

  String _statusFilter = 'Tất cả';
  String _priorityFilter = 'Tất cả';
  String _sortBy = 'Hạn hoàn thành';

  final List<TaskItem> _tasks = [
    TaskItem(
      title: 'Hoàn thành giao diện đăng nhập',
      description: 'Thiết kế và hoàn thiện giao diện đăng nhập Flutter',
      status: 'Đã hoàn thành',
      priority: 'Cao',
      startDate: DateTime.now().subtract(const Duration(days: 4)),
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TaskItem(
      title: 'Xây dựng màn hình quản lý công việc',
      description: 'Thiết kế danh sách và thẻ công việc',
      status: 'Đang thực hiện',
      priority: 'Cao',
      startDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 2)),
    ),
    TaskItem(
      title: 'Kiểm tra chức năng tìm kiếm',
      description: 'Tìm kiếm công việc theo tên',
      status: 'Chưa thực hiện',
      priority: 'Trung bình',
      startDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 4)),
    ),
    TaskItem(
      title: 'Viết báo cáo dự án',
      description: 'Tổng hợp nội dung và kết quả thực hiện',
      status: 'Chưa thực hiện',
      priority: 'Thấp',
      startDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 7)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  List<TaskItem> get _filteredTasks {
    final keyword = _searchController.text.toLowerCase().trim();

    final result = _tasks.where((task) {
      final matchName = task.title.toLowerCase().contains(keyword);
      final matchStatus =
          _statusFilter == 'Tất cả' || task.status == _statusFilter;
      final matchPriority =
          _priorityFilter == 'Tất cả' ||
              task.priority == _priorityFilter;

      return matchName && matchStatus && matchPriority;
    }).toList();

    if (_sortBy == 'Hạn hoàn thành') {
      result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } else if (_sortBy == 'Mức độ ưu tiên') {
      const order = {'Cao': 0, 'Trung bình': 1, 'Thấp': 2};
      result.sort(
            (a, b) => order[a.priority]!.compareTo(order[b.priority]!),
      );
    } else {
result.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    }

    return result;
  }

  int get _completedCount =>
      _tasks.where((task) => task.status == 'Đã hoàn thành').length;

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final emailController = TextEditingController();

final List<String> sampleMembers = [
'Tú Trinh',
'Cẩm Như',
'Thanh Ngân',
'Quỳnh Như',
];

List<String> selectedAssignees = [];
String? primaryAssignee;

    final DateTime createdDate = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));

    String priority = 'Trung bình';

    final newTask = await showDialog<TaskItem>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm công việc'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tên công việc',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Mức độ ưu tiên',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Thấp', 'Trung bình', 'Cao']
                          .map(
                            (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            priority = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Ngày tạo tự động
                    TextFormField(
                      readOnly: true,
                      initialValue: _formatDate(createdDate),
                      decoration: const InputDecoration(
                        labelText: 'Ngày tạo',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Ngày hoàn thành có thể chọn
                    InkWell(
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate,
                          firstDate: DateTime(
                            createdDate.year,
                            createdDate.month,
                            createdDate.day,
                          ),
                          lastDate: DateTime(2100),
                          helpText: 'Chọn ngày hoàn thành',
                          cancelText: 'Hủy',
                          confirmText: 'Chọn',
                        );

                        if (selectedDate != null) {
                          setDialogState(() {
                            dueDate = selectedDate;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ngày hoàn thành',
                          prefixIcon: Icon(Icons.event),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_formatDate(dueDate)),
                      ),
                    ),

// Người được giao
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Người được giao',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: taskDarkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email hoặc tài khoản thành viên',
                        hintText: 'example@gmail.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle, color: taskPrimaryBlue),
                          onPressed: () {
                            final email = emailController.text.trim();

                            if (!email.contains('@') || !email.contains('.')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập email hợp lệ'),
                                ),
                              );
                              return;
                            }

                            if (sampleMembers.contains(email)) {
                              return;
                            }

                            setDialogState(() {
                              sampleMembers.add(email);
                              selectedAssignees.add(email);
                              primaryAssignee ??= email;
                              emailController.clear();
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sampleMembers.map((member) {
                        final isSelected = selectedAssignees.contains(member);

                        return FilterChip(
                          label: Text(member),
                          selected: isSelected,
                          selectedColor: taskPrimaryBlue.withValues(alpha: 0.18),
                          checkmarkColor: taskPrimaryBlue,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedAssignees.add(member);

                                // Người đầu tiên được chọn mặc định là phụ trách chính
                                primaryAssignee ??= member;
                              } else {
                                selectedAssignees.remove(member);

                                if (primaryAssignee == member) {
                                  primaryAssignee = selectedAssignees.isNotEmpty
                                      ? selectedAssignees.first
                                      : null;
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

// Người phụ trách chính
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Người phụ trách chính',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: taskDarkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: primaryAssignee,
                          hint: const Text('Chọn người phụ trách chính'),
                          items: selectedAssignees.map((member) {
                            return DropdownMenuItem<String>(
                              value: member,
                              child: Text(member),
                            );
                          }).toList(),
                          onChanged: selectedAssignees.isEmpty
                              ? null
                              : (value) {
                            setDialogState(() {
                              primaryAssignee = value;
                            });
                          },
                        ),
                      ),
                    ),

                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên công việc!'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      TaskItem(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        priority: priority,
                        startDate: createdDate,
                        createdDate: createdDate,
                        dueDate: dueDate,
                        assignees: List<String>.from(selectedAssignees),
                        primaryAssignee: primaryAssignee,
                        assignee: primaryAssignee ?? 'Tôi',
                      ),
                    );
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 300));

    titleController.dispose();
    descriptionController.dispose();
    emailController.dispose();


    if (newTask != null && mounted) {
      try {
        final savedTask = await _createTaskOnServer(newTask);

        if (!mounted) return;

        setState(() {
          _tasks.insert(0, savedTask);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu công việc '),
          ),
        );
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu công việc: $error'),
          ),
        );
      }
    }

  }

  Future<void> _changeStatus(TaskItem task, String status) async {
    if (task.id == null || task.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Công việc chưa có ID trên máy chủ!'),
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại!');
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/api/tasks/${task.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        setState(() {
          task.status = status;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu tiến độ công việc '),
          ),
        );
      } else {
        throw Exception(data['message'] ?? 'Không thể cập nhật công việc');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật tiến độ: $error'),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Đã hoàn thành':
        return Colors.green;
      case 'Đang thực hiện':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Cao':
        return Colors.red;
      case 'Trung bình':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }


  Widget _buildTaskCard(TaskItem task) {
    final statusColor = _statusColor(task.status);
    final priorityColor = _priorityColor(task.priority);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tên công việc và menu
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: taskDarkBlue,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == 'delete') {
                      setState(() => _tasks.remove(task));
                    } else if (value == 'detail') {
final shareEmailController = TextEditingController();
String newPermission = 'Viewer';

showDialog(
context: context,
builder: (dialogContext) {
return StatefulBuilder(
builder: (dialogContext, setDialogState) {
return AlertDialog(
title: Text(task.title),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
task.description.isEmpty
? 'Chưa có mô tả.'
: task.description,
),
const SizedBox(height: 12),
Text('Ngày tạo: ${_formatDate(task.createdDate)}'),
Text('Ngày hoàn thành: ${_formatDate(task.dueDate)}'),
Text('Ưu tiên: ${task.priority}'),
Text('Trạng thái: ${task.status}'),

const Divider(height: 28),

const Text(
'Chia sẻ công việc',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),

TextField(
controller: shareEmailController,
keyboardType: TextInputType.emailAddress,
decoration: const InputDecoration(
labelText: 'Email thành viên',
hintText: 'example@gmail.com',
prefixIcon: Icon(Icons.email_outlined),
border: OutlineInputBorder(),
),
),
const SizedBox(height: 10),

DropdownButtonFormField<String>(
initialValue: newPermission,
decoration: const InputDecoration(
labelText: 'Quyền truy cập',
border: OutlineInputBorder(),
),
items: const [
DropdownMenuItem(
value: 'Viewer',
child: Text('Viewer - Chỉ xem'),
),
DropdownMenuItem(
value: 'Editor',
child: Text('Editor - Được chỉnh sửa'),
),
],
onChanged: (value) {
if (value != null) {
setDialogState(() {
newPermission = value;
});
}
},
),
const SizedBox(height: 10),

SizedBox(
width: double.infinity,
child: ElevatedButton.icon(

  onPressed: () async {
    final email = shareEmailController.text
        .trim()
        .toLowerCase();

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Email không hợp lệ!'),
        ),
      );
      return;
    }

    if (task.id == null || task.id!.isEmpty) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Công việc chưa được lưu trên máy chủ!'),
        ),
      );
      return;
    }

    if (task.sharedWith.any(
          (member) => member.email.toLowerCase() == email,
    )) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Email này đã được chia sẻ!'),
        ),
      );
      return;
    }

    try {
      final result = await _shareTaskOnServer(
        task,
        email,
        newPermission,
      );

      final members = await _loadSharedMembers(task.id!);

      if (!mounted || !dialogContext.mounted) return;

      setDialogState(() {
        task.sharedWith
          ..clear()
          ..addAll(members);

        shareEmailController.clear();
      });


      final emailSent = result['emailSent'] == true;

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            emailSent
                ? 'Đã chia sẻ công việc và gửi email thành công!'
                : 'Đã lưu chia sẻ nhưng gửi email thất bại: ${result['emailError'] ?? 'Không rõ nguyên nhân'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('Lỗi chia sẻ công việc: $error'),
        ),
      );
    }
  },

icon: const Icon(Icons.person_add_alt_1),
label: const Text('Thêm thành viên'),
),
),

const Divider(height: 28),

const Text(
'Danh sách thành viên được chia sẻ',
style: TextStyle(fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),

if (task.sharedWith.isEmpty)
const Text(
'Chưa có thành viên nào được chia sẻ.',
style: TextStyle(color: Colors.grey),
),

...task.sharedWith.map((member) {
return ListTile(
contentPadding: EdgeInsets.zero,
leading: const CircleAvatar(
child: Icon(Icons.person),
),
title: Text(
member.email,
style: const TextStyle(fontSize: 13),
),
subtitle: DropdownButton<String>(
value: member.permission,
isExpanded: true,
items: const [
DropdownMenuItem(
value: 'Viewer',
child: Text('Viewer - Chỉ xem'),
),
DropdownMenuItem(
value: 'Editor',
child: Text('Editor - Được chỉnh sửa'),
),
],
onChanged: (value) {
if (value != null) {
setDialogState(() {
member.permission = value;
});

}
},
),
trailing: IconButton(
tooltip: 'Thu hồi quyền',
icon: const Icon(
Icons.delete_outline,
color: Colors.red,
),
onPressed: () {
setDialogState(() {
task.sharedWith.remove(member);
});
setState(() {});
},
),
);
}),
],
),
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
},
).whenComplete(() {
  shareEmailController.dispose();
});
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'detail',
                      child: Text('Xem chi tiết'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa công việc'),
                    ),
                  ],
                ),
              ],
            ),

            // Mô tả
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Trạng thái và mức độ ưu tiên
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag(
                  task.status,
                  statusColor,
                  icon: Icons.circle,
                ),
                _buildTag(
                  'Ưu tiên ${task.priority.toLowerCase()}',
                  priorityColor,
                  icon: Icons.flag_outlined,
                ),
              ],
            ),

            const Divider(height: 24),

            // Ngày tạo và ngày hoàn thành
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ngày tạo: ${_formatDate(task.createdDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ngày hoàn thành: ${_formatDate(task.dueDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Thay đổi trạng thái
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: taskPrimaryBlue,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Trạng thái',
                      style: TextStyle(
                        color: taskPrimaryBlue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                onSelected: (value) => _changeStatus(task, value),
                itemBuilder: (context) => [
                  'Chưa thực hiện',
                  'Đang thực hiện',
                  'Đã hoàn thành',
                ].map(
                      (value) => PopupMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTag(String text, Color color, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Quản lý công việc',
          style: TextStyle(
            color: taskDarkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: taskDarkBlue),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Xin chào! 👋',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hôm nay bạn có kế hoạch gì?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: taskDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSummary(
                        'Tổng công việc',
                        _tasks.length.toString(),
                        Icons.assignment_outlined,
                        taskPrimaryBlue,
                      ),
                      const SizedBox(width: 10),
                      _buildSummary(
                        'Hoàn thành',
                        _completedCount.toString(),
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm công việc...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilter(
                        value: _statusFilter,
                        items: [
                          'Tất cả',
                          'Chưa thực hiện',
                          'Đang thực hiện',
                          'Đã hoàn thành',
                        ],
                        hint: 'Trạng thái',
                        onChanged: (value) =>
                            setState(() => _statusFilter = value!),
                      ),
                      const SizedBox(width: 10),
                      _buildFilter(
                        value: _priorityFilter,
                        items: ['Tất cả', 'Thấp', 'Trung bình', 'Cao'],
                        hint: 'Ưu tiên',
                        onChanged: (value) =>
                            setState(() => _priorityFilter = value!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Danh sách công việc',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: taskDarkBlue,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => setState(() => _sortBy = value),
                    child: Row(
                      children: [
                        const Icon(Icons.sort, color: taskPrimaryBlue, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _sortBy,
                          style: const TextStyle(
                            color: taskPrimaryBlue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'Hạn hoàn thành',
                        child: Text('Hạn hoàn thành'),
                      ),
                      PopupMenuItem(
                        value: 'Mức độ ưu tiên',
                        child: Text('Mức độ ưu tiên'),
                      ),
                      PopupMenuItem(
                        value: 'Thời gian tạo',
                        child: Text('Thời gian tạo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                child: Text('Không tìm thấy công việc phù hợp.'),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tasks.length,
                itemBuilder: (context, index) =>
                    _buildTaskCard(tasks[index]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: taskPrimaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm công việc'),
      ),
    );
  }

  Widget _buildSummary(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
