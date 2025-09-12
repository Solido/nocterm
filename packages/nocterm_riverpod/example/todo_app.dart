import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';

// Todo model
class Todo {
  Todo({
    required this.id,
    required this.title,
    this.completed = false,
  });

  final String id;
  final String title;
  final bool completed;

  Todo copyWith({String? title, bool? completed}) {
    return Todo(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}

// Todo list notifier
class TodoListNotifier extends ChangeNotifier {
  final List<Todo> _todos = [];
  
  List<Todo> get todos => List.unmodifiable(_todos);
  
  void addTodo(String title) {
    _todos.add(Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    ));
    notifyListeners();
  }
  
  void toggleTodo(String id) {
    final index = _todos.indexWhere((todo) => todo.id == id);
    if (index != -1) {
      _todos[index] = _todos[index].copyWith(
        completed: !_todos[index].completed,
      );
      notifyListeners();
    }
  }
  
  void removeTodo(String id) {
    _todos.removeWhere((todo) => todo.id == id);
    notifyListeners();
  }
}

// Providers
final todoListProvider = ChangeNotifierProvider((ref) => TodoListNotifier());

final completedTodosProvider = Provider<List<Todo>>((ref) {
  final todos = ref.watch(todoListProvider).todos;
  return todos.where((todo) => todo.completed).toList();
});

final incompleteTodosProvider = Provider<List<Todo>>((ref) {
  final todos = ref.watch(todoListProvider).todos;
  return todos.where((todo) => !todo.completed).toList();
});

// Filter enum
enum TodoFilter { all, active, completed }

final todoFilterProvider = StateProvider<TodoFilter>((ref) => TodoFilter.all);

final filteredTodosProvider = Provider<List<Todo>>((ref) {
  final filter = ref.watch(todoFilterProvider);
  final todos = ref.watch(todoListProvider).todos;
  
  switch (filter) {
    case TodoFilter.all:
      return todos;
    case TodoFilter.active:
      return todos.where((todo) => !todo.completed).toList();
    case TodoFilter.completed:
      return todos.where((todo) => todo.completed).toList();
  }
});

// Components
class TodoApp extends StatelessComponent {
  const TodoApp({super.key});

  @override
  Component build(BuildContext context) {
    return ProviderScope(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            TodoHeader(),
            SizedBox(height: 1),
            TodoInput(),
            SizedBox(height: 1),
            TodoFilterBar(),
            SizedBox(height: 1),
            Expanded(child: TodoList()),
            TodoStats(),
          ],
        ),
      ),
    );
  }
}

class TodoHeader extends StatelessComponent {
  const TodoHeader({super.key});

  @override
  Component build(BuildContext context) {
    return const Center(
      child: Text(
        '📝 Todo App with Riverpod',
        style: TextStyle(bold: true),
      ),
    );
  }
}

class TodoInput extends StatefulComponent {
  const TodoInput({super.key});

  @override
  State<TodoInput> createState() => _TodoInputState();
}

class _TodoInputState extends State<TodoInput> {
  final _controller = TextEditingController();
  
  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read(todoListProvider).addTodo(text);
      _controller.clear();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Component build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            placeholder: 'What needs to be done?',
            onSubmitted: (_) => _addTodo(),
          ),
        ),
        const SizedBox(width: 1),
        TextButton(
          onPressed: _addTodo,
          child: const Text('[Add]'),
        ),
      ],
    );
  }
}

class TodoFilterBar extends StatelessComponent {
  const TodoFilterBar({super.key});

  @override
  Component build(BuildContext context) {
    final currentFilter = context.watch(todoFilterProvider);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final filter in TodoFilter.values) ...[
          TextButton(
            onPressed: () {
              context.read(todoFilterProvider.notifier).state = filter;
            },
            child: Text(
              '[${filter.name}]',
              style: TextStyle(
                bold: currentFilter == filter,
                foregroundColor: currentFilter == filter ? Color.cyan : null,
              ),
            ),
          ),
          if (filter != TodoFilter.values.last) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

class TodoList extends StatefulComponent {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  int _selectedIndex = 0;
  
  @override
  Component build(BuildContext context) {
    final todos = context.watch(filteredTodosProvider);
    
    if (todos.isEmpty) {
      return const Center(
        child: Text(
          'No todos yet!',
          style: TextStyle(dim: true),
        ),
      );
    }
    
    return KeyboardListener(
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowUp) {
          setState(() {
            _selectedIndex = (_selectedIndex - 1).clamp(0, todos.length - 1);
          });
        } else if (event.logicalKey == LogicalKey.arrowDown) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1).clamp(0, todos.length - 1);
          });
        } else if (event.logicalKey == LogicalKey.space) {
          if (_selectedIndex < todos.length) {
            context.read(todoListProvider).toggleTodo(todos[_selectedIndex].id);
          }
        } else if (event.logicalKey == LogicalKey.delete) {
          if (_selectedIndex < todos.length) {
            context.read(todoListProvider).removeTodo(todos[_selectedIndex].id);
            // Adjust selected index if needed
            if (_selectedIndex >= todos.length - 1 && _selectedIndex > 0) {
              setState(() {
                _selectedIndex--;
              });
            }
          }
        }
      },
      child: ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          final isSelected = index == _selectedIndex;
          
          return Container(
            color: isSelected ? Color.blue.withOpacity(0.3) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                children: [
                  Text(
                    todo.completed ? '[✓]' : '[ ]',
                    style: TextStyle(
                      foregroundColor: todo.completed ? Color.green : null,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: Text(
                      todo.title,
                      style: TextStyle(
                        strikethrough: todo.completed,
                        dim: todo.completed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TodoStats extends StatelessComponent {
  const TodoStats({super.key});

  @override
  Component build(BuildContext context) {
    final total = context.watch(todoListProvider).todos.length;
    final completed = context.watch(completedTodosProvider).length;
    final remaining = context.watch(incompleteTodosProvider).length;
    
    return Container(
      color: Color.black,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('Total: $total'),
            Text(
              'Active: $remaining',
              style: const TextStyle(foregroundColor: Color.yellow),
            ),
            Text(
              'Completed: $completed',
              style: const TextStyle(foregroundColor: Color.green),
            ),
          ],
        ),
      ),
    );
  }
}

class TextButton extends StatelessComponent {
  const TextButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  
  final VoidCallback onPressed;
  final Component child;
  
  @override
  Component build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: child,
    );
  }
}

// Main function
void main() {
  runApp(const TodoApp());
}

// Instructions component for help
class TodoInstructions extends StatelessComponent {
  const TodoInstructions({super.key});

  @override
  Component build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Controls:', style: TextStyle(bold: true)),
        Text('↑/↓ - Navigate todos'),
        Text('Space - Toggle todo'),
        Text('Delete - Remove todo'),
        Text('Tab - Switch between input and list'),
      ],
    );
  }
}