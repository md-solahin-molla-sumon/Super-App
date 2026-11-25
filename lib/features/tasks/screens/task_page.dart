import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/task_service.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final TaskService _taskService = TaskService();

  Future<void> _showTaskDialog({
    String? taskId,
    String title = '',
    String description = '',
    DateTime? dueDate,
  }) async {
    final titleController = TextEditingController(text: title);
    final descriptionController = TextEditingController(text: description);

    DateTime selectedDate = dueDate ?? DateTime.now();

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(taskId == null ? 'Add New Task' : 'Edit Task'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Task Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (!dialogContext.mounted) return;

                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                              );
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          '${selectedDate.day}/'
                          '${selectedDate.month}/'
                          '${selectedDate.year}',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter task title.'),
                          ),
                        );
                        return;
                      }

                      try {
                        if (taskId == null) {
                          await _taskService.addTask(
                            title: titleController.text,
                            description: descriptionController.text,
                            dueDate: selectedDate,
                          );
                        } else {
                          await _taskService.updateTask(
                            taskId: taskId,
                            title: titleController.text,
                            description: descriptionController.text,
                            dueDate: selectedDate,
                          );
                        }

                        if (!dialogContext.mounted) return;

                        Navigator.pop(dialogContext);
                      } catch (e) {
                        if (!dialogContext.mounted) return;

                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await _taskService.deleteTask(taskId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('To-Do & Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _taskService.getTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data?.docs ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt, size: 65, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tasks yet.', style: TextStyle(fontSize: 17)),
                  SizedBox(height: 5),
                  Text(
                    'Tap Add Task to create your first task.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final completedCount = tasks.where((task) {
            return task.data()['isCompleted'] == true;
          }).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Tasks',
                        tasks.length.toString(),
                        Icons.list_alt,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryCard(
                        'Completed',
                        completedCount.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryCard(
                        'Pending',
                        (tasks.length - completedCount).toString(),
                        Icons.pending_actions,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final document = tasks[index];
                    final data = document.data();

                    final taskTitle = data['title'] as String? ?? '';

                    final description = data['description'] as String? ?? '';

                    final isCompleted = data['isCompleted'] as bool? ?? false;

                    final timestamp = data['dueDate'] as Timestamp?;

                    final date = timestamp?.toDate() ?? DateTime.now();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Checkbox(
                          value: isCompleted,
                          onChanged: (value) async {
                            try {
                              await _taskService.toggleTaskStatus(
                                taskId: document.id,
                                isCompleted: value ?? false,
                              );
                            } catch (e) {
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                        ),
                        title: Text(
                          taskTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: isCompleted ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Due: ${_formatDate(date)}'),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(description),
                              ],
                              const SizedBox(height: 5),
                              Text(
                                isCompleted ? 'Completed' : 'Pending',
                                style: TextStyle(
                                  color: isCompleted
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showTaskDialog(
                                taskId: document.id,
                                title: taskTitle,
                                description: description,
                                dueDate: date,
                              );
                            } else if (value == 'delete') {
                              _deleteTask(document.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              count,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
