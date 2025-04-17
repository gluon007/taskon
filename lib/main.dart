import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  final ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo App',
      theme: ThemeData.dark(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: TodoList(),
    );
  }
}

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  TodoListState createState() => TodoListState();
}

class TodoListState extends State<TodoList> {
  List<Todo> _todos = [];
  List<Todo> _completedTodos = [];
  int _credits = 0;
  final TextEditingController _textFieldController = TextEditingController();
  final TextEditingController _durationFieldController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _loadCredits();
    _loadCompletedTodos();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todoStrings = prefs.getStringList('todos') ?? [];
    setState(() {
      _todos = todoStrings.map((str) => Todo.fromString(str)).toList();
    });
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todoStrings = _todos.map((todo) => todo.toString()).toList();
    await prefs.setStringList('todos', todoStrings);
  }

  Future<void> _loadCompletedTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final completedTodoStrings = prefs.getStringList('completedTodos') ?? [];
    setState(() {
      _completedTodos = completedTodoStrings.map((str) => Todo.fromJson(jsonDecode(str))).toList();
    });
  }

  Future<void> _saveCompletedTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final completedTodoStrings = _completedTodos.map((todo) => jsonEncode(todo.toJson())).toList();
    await prefs.setStringList('completedTodos', completedTodoStrings);
  }

  Future<void> _loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _credits = prefs.getInt('credits') ?? 0;
    });
  }

  Future<void> _saveCredits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('credits', _credits);
  }

  void _addTodoItem(String title, int duration) {
    setState(() {
      _todos.add(Todo(title: title, duration: duration));
    });
    _saveTodos();
  }

  void _markTodoAsComplete(Todo todo) async {
    await SharedPreferences.getInstance();
    _completedTodos.add(todo);
    await _saveCompletedTodos();

    setState(() {
      _todos.remove(todo);
    });
    _saveTodos();
    _calculateCredits(todo);
  }

  void _discardTodo(Todo todo) {
    setState(() {
      _todos.remove(todo);
      _credits -= 1;
    });
    _saveTodos();
    _saveCredits();
  }

  void _calculateCredits(Todo todo) {
    DateTime now = DateTime.now();
    DateTime completionTime = now.add(Duration(minutes: todo.duration));
    if (now.isBefore(completionTime)) {
      _credits += 5;
    } else {
      _credits += 2;
    }
    _saveCredits();
  }

  Future<void> _displayDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add a todo item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textFieldController,
                decoration: const InputDecoration(hintText: 'Enter todo here'),
              ),
              TextField(
                controller: _durationFieldController,
                decoration: const InputDecoration(
                  hintText: 'Enter duration (minutes)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                Navigator.of(context).pop();
                _addTodoItem(
                  _textFieldController.text,
                  int.parse(_durationFieldController.text),
                );
                _textFieldController.clear();
                _durationFieldController.clear();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todo List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Credits: $_credits'),
          ),
          Expanded(
            child: ListView(
              children: [
                ..._todos.map(
                  (Todo todo) => TodoItem(
                    todo: todo,
                    onComplete: () => _markTodoAsComplete(todo),
                    onRemove: () => _discardTodo(todo),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Completed Tasks'),
                ),
                ..._completedTodos.map(
                  (Todo todo) => Card(
                    child: ListTile(
                      title: Text(todo.title),
                      subtitle: Text('Duration: ${todo.duration} minutes'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _displayDialog(),
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TodoItem extends StatelessWidget {
  const TodoItem({
    super.key,
    required this.todo,
    required this.onComplete,
    required this.onRemove,
  });

  final Todo todo;
  final VoidCallback onComplete;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(todo.title),
        subtitle: Text('Duration: ${todo.duration} minutes'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.check), onPressed: onComplete),
            IconButton(icon: const Icon(Icons.delete), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

class Todo {
  Todo({required this.title, required this.duration, this.isCompleted = false});

  String title;
  int duration;
  bool isCompleted;

  @override
  String toString() {
    return '$title,$duration,$isCompleted';
  }

  Todo.fromString(String str)
    : title = str.split(',')[0],
      duration = int.parse(str.split(',')[1]),
      isCompleted = str.split(',')[2].toLowerCase() == 'true';

  Map<String, dynamic> toJson() => {
    'title': title,
    'duration': duration,
    'isCompleted': isCompleted,
  };

  Todo.fromJson(Map<String, dynamic> json)
    : title = json['title'],
      duration = json['duration'],
      isCompleted = json['isCompleted'];
}
