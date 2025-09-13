import 'package:nocterm/nocterm.dart';

void main() {
  runApp(const FullColorTest());
}

class FullColorTest extends StatelessComponent {
  const FullColorTest({super.key});

  @override
  Component build(BuildContext context) {
    return Container(
      color: Colors.red,
      child: Text('Hello, World!'),
    );
  }
}
