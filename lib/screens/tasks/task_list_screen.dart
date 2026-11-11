
import 'package:flutter/material.dart';

const Color taskPrimaryBlue = Color(0xFF2475ED);
const Color taskDarkBlue = Color(0xFF26344D);


class TaskItem {
  String title;
  String description;
  String status;
  String priority;
  DateTime startDate;
  DateTime createdDate;
  DateTime dueDate;
  String assignee;

  TaskItem({
    required this.title,
    this.description = '',
    this.status = 'Chưa thực hiện',
    this.priority = 'Trung bình',
    required this.startDate,
    DateTime? createdDate,
    required this.dueDate,
    this.assignee = 'Tôi',
  }) : createdDate = createdDate ?? DateTime.now();
}


class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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


  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final DateTime createdDate = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));

    String priority = 'Trung bình';

    showDialog(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên công việc!'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _tasks.add(
                        TaskItem(
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          priority: priority,
                          startDate: createdDate,
                          createdDate: createdDate,
                          dueDate: dueDate,
                        ),
                      );
                    });

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã thêm công việc!'),
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
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  void _changeStatus(TaskItem task, String status) {
    setState(() {
      task.status = status;
    });
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
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(task.title),
                          content: Column(
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
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Đóng'),
                            ),
                          ],
                        ),
                      );
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
