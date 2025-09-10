import 'package:nocterm/nocterm.dart';

void main() async {
  await runApp(const ListViewAddDemo());
}

class ListViewAddDemo extends StatefulComponent {
  const ListViewAddDemo({super.key});

  @override
  State<ListViewAddDemo> createState() => _ListViewAddDemoState();
}

class _ListViewAddDemoState extends State<ListViewAddDemo> {
  final List<String> items = ['Item 1', 'Item 2', 'Item 3'];
  final ScrollController scrollController = ScrollController();
  int itemCounter = 4;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      items.add('Item $itemCounter');
      itemCounter++;
    });
    
    // Scroll to bottom after adding item
    Future.delayed(Duration(milliseconds: 100), () {
      scrollController.scrollToEnd();
    });
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.keyA) {
      _addItem();
      return true;
    } else if (event.logicalKey == LogicalKey.keyC) {
      // Clear list with 'c'
      setState(() {
        items.clear();
        itemCounter = 1;
      });
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: BoxBorder.all(color: Colors.cyan),
              color: Color.fromRGB(0, 40, 80),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ListView Demo - Press "a" to add items',
                  style: TextStyle(
                    color: Colors.brightWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Items: ${items.length}',
                  style: TextStyle(color: Colors.yellow),
                ),
              ],
            ),
          ),
          
          // Main content area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.blue),
              ),
              child: Column(
                children: [
                  // Instructions
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: Color.fromRGB(20, 20, 40),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Press ', style: TextStyle(color: Colors.gray)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            border: BoxBorder.all(color: Colors.green),
                          ),
                          child: Text('a', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                        Text(' to add item | ', style: TextStyle(color: Colors.gray)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            border: BoxBorder.all(color: Colors.red),
                          ),
                          child: Text('c', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                        Text(' to clear | ', style: TextStyle(color: Colors.gray)),
                        Text('↑↓ to scroll', style: TextStyle(color: Colors.gray)),
                      ],
                    ),
                  ),
                  
                  // ListView with scrollbar
                  Expanded(
                    child: Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      thickness: 1,
                      child: items.isEmpty
                          ? Center(
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  border: BoxBorder.all(color: Colors.gray),
                                ),
                                child: Text(
                                  'List is empty - Press "a" to add items',
                                  style: TextStyle(color: Colors.gray),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.all(1),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final isEven = index % 2 == 0;
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isEven 
                                      ? Color.fromRGB(30, 30, 40)
                                      : Color.fromRGB(20, 20, 30),
                                    border: BoxBorder(
                                      bottom: BorderSide(color: Colors.gray),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 5,
                                        child: Text(
                                          '[${(index + 1).toString().padLeft(3, '0')}]',
                                          style: TextStyle(
                                            color: Colors.cyan,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          items[index],
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      Text(
                                        'New!',
                                        style: TextStyle(color: Colors.gray),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  
                  // Status bar
                  Container(
                    padding: EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      border: BoxBorder(top: BorderSide(color: Colors.blue)),
                      color: Color.fromRGB(0, 20, 40),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          scrollController.maxScrollExtent > 0
                            ? 'Scroll: ${((scrollController.offset / scrollController.maxScrollExtent) * 100).toStringAsFixed(0)}%'
                            : 'No scrolling needed',
                          style: TextStyle(color: Colors.green),
                        ),
                        Text(
                          'Last action: ${items.isEmpty ? "Cleared" : "Added ${items.last}"}',
                          style: TextStyle(color: Colors.yellow),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}