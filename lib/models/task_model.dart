class Task {
  final String id;
  final String title;
  final String description;
  final String status; // 'pending', 'in_progress', 'completed'
  final DateTime dueDate;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
  });
}
