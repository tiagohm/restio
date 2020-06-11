class Task {
  final String name;

  const Task(this.name);

  factory Task.fromJson(dynamic item) {
    return Task(item['name']);
  }
}
