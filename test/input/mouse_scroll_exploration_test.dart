import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// Exploration tests to understand current mouse support behavior and identify issues.
/// This file documents the current state of mouse support for planning improvements.
void main() {
  group('Mouse Wheel Scrolling - ListView', () {
    test('basic wheel scroll down in ListView', () async {
      await testNocterm(
        'ListView wheel scroll down',
        (tester) async {
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          );

          expect(tester.terminalState, containsText('Item 0'));
          expect(controller.offset, 0);

          // Send wheel down event at position inside the ListView
          await tester.sendMouseEvent(MouseEvent(
            button: MouseButton.wheelDown,
            x: 20,
            y: 5,
            pressed: true, // Wheel events use pressed=true
          ));

          // Should have scrolled down by 3 lines
          expect(controller.offset, 3);
          expect(tester.terminalState, containsText('Item 3'));
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });

    test('wheel scroll up in ListView', () async {
      await testNocterm(
        'ListView wheel scroll up',
        (tester) async {
          final controller = ScrollController(initialScrollOffset: 10);

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          );

          expect(controller.offset, 10);

          // Send wheel up event
          await tester.sendMouseEvent(MouseEvent(
            button: MouseButton.wheelUp,
            x: 20,
            y: 5,
            pressed: true,
          ));

          // Should have scrolled up by 3 lines
          expect(controller.offset, 7);
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });

    test('wheel scroll respects boundaries', () async {
      await testNocterm(
        'ListView scroll boundaries',
        (tester) async {
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                controller: controller,
                itemCount:
                    5, // Only 5 items, content may be shorter than viewport
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          );

          // Try to scroll up when already at top
          await tester.sendMouseEvent(MouseEvent(
            button: MouseButton.wheelUp,
            x: 20,
            y: 5,
            pressed: true,
          ));

          expect(controller.offset, 0, reason: 'Should not scroll past top');
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });
  });

  group('Mouse Wheel Scrolling - SingleChildScrollView', () {
    test('basic wheel scroll in SingleChildScrollView', () async {
      await testNocterm(
        'SCSV wheel scroll',
        (tester) async {
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: List.generate(30, (i) => Text('Line $i')),
                ),
              ),
            ),
          );

          expect(controller.offset, 0);

          // Send wheel down
          await tester.sendMouseEvent(MouseEvent(
            button: MouseButton.wheelDown,
            x: 20,
            y: 5,
            pressed: true,
          ));

          expect(controller.offset, 3);
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });

    test('horizontal scroll with wheel', () async {
      await testNocterm(
        'horizontal SCSV wheel scroll',
        (tester) async {
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 20,
              height: 5,
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                        'This is a very long text that needs horizontal scrolling'),
                  ],
                ),
              ),
            ),
          );

          expect(controller.offset, 0);

          // Wheel down should scroll horizontally
          await tester.sendMouseEvent(MouseEvent(
            button: MouseButton.wheelDown,
            x: 10,
            y: 2,
            pressed: true,
          ));

          expect(controller.offset, 3);
        },
        debugPrintAfterPump: true,
        size: Size(30, 10),
      );
    });
  });

  group('Mouse Click/Tap in Scrollable Lists', () {
    test('tap on item in ListView', () async {
      await testNocterm(
        'tap ListView item',
        (tester) async {
          int? tappedIndex;

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => tappedIndex = index,
                  child: Container(
                    height: 1,
                    child: Text('Tappable Item $index'),
                  ),
                ),
              ),
            ),
          );

          // Tap on item at y=3 (should be item 3)
          await tester.tap(20, 3);

          expect(tappedIndex, 3);
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });

    test('tap on item after scrolling ListView', () async {
      await testNocterm(
        'tap after scroll',
        (tester) async {
          int? tappedIndex;
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => tappedIndex = index,
                  child: Container(
                    height: 1,
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          );

          // Scroll down first
          controller.scrollDown(10);
          await tester.pump();

          // Now tap on visual y=3 - should be item 13 (10 + 3)
          await tester.tap(20, 3);

          // POTENTIAL BUG: Hit testing may not account for scroll offset
          expect(tappedIndex, 13,
              reason:
                  'After scrolling 10 items, tap at y=3 should hit item 13');
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });

    test('tap on partially visible item', () async {
      await testNocterm(
        'tap partial item',
        (tester) async {
          int? tappedIndex;
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => tappedIndex = index,
                  child: Container(
                    height: 2, // 2-line items
                    child: Text('Two-line Item $index'),
                  ),
                ),
              ),
            ),
          );

          // Scroll by 1 line so items are partially visible
          controller.jumpTo(1);
          await tester.pump();

          // Tap at y=0 - should hit item 0 or item 1?
          await tester.tap(20, 0);

          // Document actual behavior
          print('Tapped index after partial scroll: $tappedIndex');
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });
  });

  group('Mouse Hover in Scrollable Lists', () {
    test('hover tracking in ListView', () async {
      await testNocterm(
        'ListView hover',
        (tester) async {
          int? hoveredIndex;

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) => MouseRegion(
                  onEnter: (_) => hoveredIndex = index,
                  child: Container(
                    height: 1,
                    child: Text('Hoverable Item $index'),
                  ),
                ),
              ),
            ),
          );

          // Hover over y=5
          await tester.hover(20, 5);

          expect(hoveredIndex, 5);
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });

    test('hover after scroll - position mapping', () async {
      await testNocterm(
        'hover after scroll',
        (tester) async {
          int? hoveredIndex;
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => MouseRegion(
                  onEnter: (_) => hoveredIndex = index,
                  child: Container(
                    height: 1,
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          );

          // Scroll down 10 items
          controller.scrollDown(10);
          await tester.pump();

          // Hover at y=2
          await tester.hover(20, 2);

          // POTENTIAL BUG: hover position may not account for scroll
          expect(hoveredIndex, 12,
              reason:
                  'After scrolling 10 items, hover at y=2 should hit item 12');
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });
  });

  group('Mouse Drag/Selection in Lists', () {
    test('mouse drag creates motion events', () async {
      await testNocterm(
        'drag motion events',
        (tester) async {
          final motionEvents = <MouseEvent>[];

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: MouseRegion(
                onHover: (event) {
                  if (event.isMotion) {
                    motionEvents.add(event);
                  }
                },
                child: Container(
                  width: 40,
                  height: 10,
                  child: Text('Drag area'),
                ),
              ),
            ),
          );

          // Perform a drag
          await tester.mouseMove(5, 2, 35, 8);

          // Check if motion events were captured
          print('Captured ${motionEvents.length} motion events');
          for (final event in motionEvents) {
            print(
                '  Motion: (${event.x}, ${event.y}) pressed=${event.pressed} isMotion=${event.isMotion}');
          }
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });

    test('drag detection in GestureDetector - no pan support yet', () async {
      await testNocterm(
        'no pan gesture',
        (tester) async {
          // GestureDetector currently doesn't support onPan/onDrag
          // This test documents the missing functionality

          bool tapDetected = false;

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: GestureDetector(
                onTap: () => tapDetected = true,
                // onPanStart: ... // NOT SUPPORTED
                // onPanUpdate: ... // NOT SUPPORTED
                // onPanEnd: ... // NOT SUPPORTED
                child: Container(
                  width: 40,
                  height: 10,
                  child: Text('No pan support'),
                ),
              ),
            ),
          );

          await tester.tap(20, 5);
          expect(tapDetected, isTrue);

          // NOTE: Drag selection would require onPan gestures
          // which are not yet implemented
        },
        debugPrintAfterPump: true,
        size: Size(50, 15),
      );
    });
  });

  group('Mouse Events in Nested Scrollables', () {
    test('wheel scroll in nested scroll views', () async {
      await testNocterm(
        'nested scroll wheel',
        (tester) async {
          final outerController = ScrollController();
          final innerController = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 15,
              child: SingleChildScrollView(
                controller: outerController,
                child: Column(
                  children: [
                    Text('Outer header'),
                    Container(
                      height: 8,
                      child: ListView.builder(
                        controller: innerController,
                        itemCount: 20,
                        itemBuilder: (context, index) => Text('Inner $index'),
                      ),
                    ),
                    for (int i = 0; i < 20; i++) Text('Outer item $i'),
                  ],
                ),
              ),
            ),
          );

          // Wheel inside inner ListView area (y=2 to y=9)
          await tester.sendMouseEvent(MouseEvent(
            button: MouseButton.wheelDown,
            x: 20,
            y: 5, // Inside inner list
            pressed: true,
          ));

          print('Inner offset: ${innerController.offset}');
          print('Outer offset: ${outerController.offset}');

          // Document which scrollable receives the event
        },
        debugPrintAfterPump: true,
        size: Size(50, 20),
      );
    });
  });

  group('Mouse Position Coordinate System', () {
    test('verify 0-based coordinates from parser', () async {
      await testNocterm(
        'coordinate verification',
        (tester) async {
          int? lastX, lastY;

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: MouseRegion(
                onHover: (event) {
                  lastX = event.x;
                  lastY = event.y;
                },
                child: Container(
                  width: 40,
                  height: 10,
                  child: Text('Click test'),
                ),
              ),
            ),
          );

          // Hover at terminal position (0,0)
          await tester.hover(0, 0);
          expect(lastX, 0, reason: 'x should be 0-based');
          expect(lastY, 0, reason: 'y should be 0-based');

          // Hover at (10, 5)
          await tester.hover(10, 5);
          expect(lastX, 10);
          expect(lastY, 5);
        },
        size: Size(50, 15),
      );
    });

    test('hit test with offset containers', () async {
      await testNocterm(
        'offset container hit test',
        (tester) async {
          bool boxHit = false;

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 20,
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    top: 5,
                    child: GestureDetector(
                      onTap: () => boxHit = true,
                      child: Container(
                        width: 15,
                        height: 8,
                        decoration: BoxDecoration(
                          border: BoxBorder.all(color: Colors.red),
                        ),
                        child: Text('Target'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          // Tap inside the positioned box (10+7, 5+4)
          await tester.tap(17, 9);
          expect(boxHit, isTrue, reason: 'Should hit positioned box');

          boxHit = false;

          // Tap outside the positioned box
          await tester.tap(5, 5);
          expect(boxHit, isFalse, reason: 'Should miss positioned box');
        },
        debugPrintAfterPump: true,
        size: Size(50, 25),
      );
    });
  });

  group('Regression: Known Issues', () {
    test('ISSUE: scroll position not updating hit test', () async {
      // This test explores potential scroll+hit test issues
      await testNocterm(
        'scroll hit test sync',
        (tester) async {
          final taps = <int>[];
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 8,
              child: ListView.builder(
                controller: controller,
                itemCount: 30,
                itemBuilder: (context, index) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    taps.add(index);
                    print('Tapped item $index');
                  },
                  child: Container(
                    height: 1,
                    child: Text('[$index] Tap me'),
                  ),
                ),
              ),
            ),
          );

          // Tap first visible item
          await tester.tap(20, 0);
          print('After first tap, taps=$taps');

          // Scroll down
          for (int i = 0; i < 5; i++) {
            await tester.sendMouseEvent(MouseEvent(
              button: MouseButton.wheelDown,
              x: 20,
              y: 4,
              pressed: true,
            ));
          }
          print('After scrolling, offset=${controller.offset}');

          // Tap at same visual position
          await tester.tap(20, 0);
          print('After second tap, taps=$taps');

          // The second tap should hit a different item than the first
          if (taps.length == 2) {
            expect(taps[0] != taps[1], isTrue,
                reason:
                    'Same visual position should hit different items after scroll');
          }
        },
        debugPrintAfterPump: true,
        size: Size(50, 12),
      );
    });

    test('ISSUE: rapid scroll wheel events', () async {
      // Test if rapid wheel events are handled correctly
      await testNocterm(
        'rapid wheel events',
        (tester) async {
          final controller = ScrollController();

          await tester.pumpComponent(
            Container(
              width: 40,
              height: 10,
              child: ListView.builder(
                controller: controller,
                itemCount: 100,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          );

          final startOffset = controller.offset;

          // Send many rapid wheel events
          for (int i = 0; i < 10; i++) {
            await tester.sendMouseEvent(MouseEvent(
              button: MouseButton.wheelDown,
              x: 20,
              y: 5,
              pressed: true,
            ));
          }

          final expectedOffset = startOffset + (10 * 3); // 3 lines per wheel
          print(
              'Expected offset: $expectedOffset, actual: ${controller.offset}');

          expect(controller.offset, expectedOffset,
              reason: 'All wheel events should be processed');
        },
        size: Size(50, 15),
      );
    });
  });
}
