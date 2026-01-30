import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';

/// Scrolling List Benchmark
///
/// Tests: Virtualization efficiency, scroll performance
/// Data: 1000 items, 20 visible at a time
void main() async {
  await runApp(const ScrollingListApp());
}

class ScrollingListApp extends StatefulComponent {
  const ScrollingListApp({super.key});

  @override
  State<ScrollingListApp> createState() => _ScrollingListAppState();
}

class _ScrollingListAppState extends State<ScrollingListApp> {
  static const int itemCount = 1000;
  static const int visibleCount = 20;

  final ScrollController _scrollController = ScrollController();
  bool _firstFrameEmitted = false;
  late final Stopwatch _stopwatch;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _emitFirstFrame() {
    if (!_firstFrameEmitted) {
      _firstFrameEmitted = true;
      final startupMs = _stopwatch.elapsedMicroseconds / 1000;
      stderr.writeln(jsonEncode({'event': 'first_frame', 'timeMs': startupMs}));
    }
  }

  void _emitScrollEvent() {
    final timeMs = _stopwatch.elapsedMicroseconds / 1000;
    stderr.writeln(jsonEncode({
      'event': 'scroll',
      'timeMs': timeMs,
      'selectedIndex': _selectedIndex,
      'scrollOffset': _scrollController.offset,
    }));
  }

  void _scrollUp() {
    NoctermTimeline.startSync('scroll_up');
    if (_selectedIndex > 0) {
      setState(() {
        _selectedIndex--;
      });
      _scrollController.jumpTo((_selectedIndex).toDouble());
      _emitScrollEvent();
    }
    NoctermTimeline.finishSync();
  }

  void _scrollDown() {
    NoctermTimeline.startSync('scroll_down');
    if (_selectedIndex < itemCount - 1) {
      setState(() {
        _selectedIndex++;
      });
      _scrollController.jumpTo((_selectedIndex).toDouble());
      _emitScrollEvent();
    }
    NoctermTimeline.finishSync();
  }

  void _pageUp() {
    NoctermTimeline.startSync('page_up');
    setState(() {
      _selectedIndex = (_selectedIndex - visibleCount).clamp(0, itemCount - 1);
    });
    _scrollController.jumpTo((_selectedIndex).toDouble());
    _emitScrollEvent();
    NoctermTimeline.finishSync();
  }

  void _pageDown() {
    NoctermTimeline.startSync('page_down');
    setState(() {
      _selectedIndex = (_selectedIndex + visibleCount).clamp(0, itemCount - 1);
    });
    _scrollController.jumpTo((_selectedIndex).toDouble());
    _emitScrollEvent();
    NoctermTimeline.finishSync();
  }

  @override
  Component build(BuildContext context) {
    // Emit first frame timing after build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _emitFirstFrame();
    });

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.keyQ) {
          shutdownApp();
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowUp) {
          _scrollUp();
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowDown) {
          _scrollDown();
          return true;
        }
        if (event.logicalKey == LogicalKey.pageUp) {
          _pageUp();
          return true;
        }
        if (event.logicalKey == LogicalKey.pageDown) {
          _pageDown();
          return true;
        }
        return false;
      },
      child: Container(
        decoration: BoxDecoration(color: Color(0xFF0f0f23)),
        child: Column(
          children: [
            // Header
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: Color(0xFF1a1a2e),
                border: BoxBorder(bottom: BorderSide(color: Color(0xFF3b82f6))),
              ),
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scrolling List Benchmark',
                    style: TextStyle(
                      color: Color(0xFF3b82f6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Item ${_selectedIndex + 1} of $itemCount',
                    style: TextStyle(color: Color(0xFF6b7280)),
                  ),
                ],
              ),
            ),
            // List area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: itemCount,
                itemExtent: 1,
                lazy: true,
                cacheExtent: 5,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedIndex;
                  return Container(
                    height: 1,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFF3b82f6)
                          : (index.isEven
                              ? Color(0xFF1a1a2e)
                              : Color(0xFF0f0f23)),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: [
                        Text(
                          isSelected ? '>' : ' ',
                          style: TextStyle(
                            color: isSelected
                                ? Color(0xFFffffff)
                                : Color(0xFF0f0f23),
                          ),
                        ),
                        SizedBox(width: 1),
                        Text(
                          'Item ${index + 1}',
                          style: TextStyle(
                            color: isSelected
                                ? Color(0xFFffffff)
                                : Color(0xFFa0a0a0),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Spacer(),
                        Text(
                          _getItemDescription(index),
                          style: TextStyle(
                            color: isSelected
                                ? Color(0xFFdbeafe)
                                : Color(0xFF6b7280),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Footer
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: Color(0xFF1a1a2e),
                border: BoxBorder(top: BorderSide(color: Color(0xFF3b82f6))),
              ),
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '↑/↓ Scroll  PgUp/PgDn Page  Q Quit',
                    style: TextStyle(color: Color(0xFF6b7280)),
                  ),
                  Text(
                    'Nocterm',
                    style: TextStyle(color: Color(0xFF4b5563)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getItemDescription(int index) {
    final descriptions = [
      'Primary task',
      'Secondary item',
      'Important',
      'Low priority',
      'Pending review',
    ];
    return descriptions[index % descriptions.length];
  }
}
