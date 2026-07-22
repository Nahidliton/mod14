import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/providers/task_provider.dart';
import '../../models/task_model.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;
  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _assignToController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  late String _selectedStatus;
  late String _initialStatus;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _assignToController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _selectedStatus = widget.task!.status;
      _initialStatus = widget.task!.status;
    } else {
      _selectedStatus = 'pending';
      _initialStatus = 'pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Task' : 'Add New Task'),
        backgroundColor: const Color(0xFF00C853),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Task' : 'Add New Task',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text('Title', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _assignToController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter title'
                    : null,
              ),
              const SizedBox(height: 24),
              const Text('Description', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 24),
              const Text('Status', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusOption('pending', 'Pending'),
                  _buildStatusOption('in_progress', 'In Progress'),
                  _buildStatusOption('completed', 'Complete'),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = _initialStatus;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _saveTask,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isEdit ? 'Save' : 'Add Task',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(String value, String label) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedStatus = value;
        });
      },
      selectedColor: const Color(0xFF00C853),
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
    );
  }

  void _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final provider = context.read<TaskProvider>();
    final title = _assignToController.text.trim();
    final description = _descriptionController.text.trim();

    bool success = false;
    if (widget.task == null) {
      success = await provider.createTask(title, description, _selectedStatus);
    } else {
      final updated = Task(
        id: widget.task!.id,
        title: title,
        description: description,
        status: _selectedStatus,
        dueDate: widget.task!.dueDate,
      );
      success = await provider.updateTask(updated);
    }

    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _assignToController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
