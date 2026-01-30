import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { Box, Text, useInput, useApp } from 'ink';

const TOTAL_ITEMS = 1000;
const VISIBLE_ITEMS = 20;

interface ListItem {
  id: number;
  label: string;
  value: number;
}

interface ScrollingListProps {
  onFirstRender: () => void;
  onFrame: (frameIndex: number, frameTime: number) => void;
}

export const ScrollingList: React.FC<ScrollingListProps> = ({ onFirstRender, onFrame }) => {
  const [scrollOffset, setScrollOffset] = useState(0);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [frameIndex, setFrameIndex] = useState(0);
  const { exit } = useApp();

  // Generate all items once (simulating a large dataset)
  const allItems = useMemo<ListItem[]>(() => {
    return Array.from({ length: TOTAL_ITEMS }, (_, i) => ({
      id: i,
      label: `Item ${i + 1}`,
      value: Math.floor(Math.random() * 1000),
    }));
  }, []);

  // Virtualization: only get the visible items
  const visibleItems = useMemo(() => {
    return allItems.slice(scrollOffset, scrollOffset + VISIBLE_ITEMS);
  }, [allItems, scrollOffset]);

  useEffect(() => {
    onFirstRender();
  }, [onFirstRender]);

  const measureFrame = useCallback((newFrameIndex: number) => {
    const frameStart = performance.now();
    setTimeout(() => {
      const frameTime = performance.now() - frameStart;
      onFrame(newFrameIndex, frameTime);
    }, 0);
  }, [onFrame]);

  const scrollUp = useCallback(() => {
    setSelectedIndex((prev) => {
      const newIndex = Math.max(0, prev - 1);
      // Adjust scroll offset if needed
      if (newIndex < scrollOffset) {
        setScrollOffset(newIndex);
      }
      return newIndex;
    });
    setFrameIndex((prev) => {
      const newIndex = prev + 1;
      measureFrame(newIndex);
      return newIndex;
    });
  }, [scrollOffset, measureFrame]);

  const scrollDown = useCallback(() => {
    setSelectedIndex((prev) => {
      const newIndex = Math.min(TOTAL_ITEMS - 1, prev + 1);
      // Adjust scroll offset if needed
      if (newIndex >= scrollOffset + VISIBLE_ITEMS) {
        setScrollOffset(newIndex - VISIBLE_ITEMS + 1);
      }
      return newIndex;
    });
    setFrameIndex((prev) => {
      const newIndex = prev + 1;
      measureFrame(newIndex);
      return newIndex;
    });
  }, [scrollOffset, measureFrame]);

  const pageUp = useCallback(() => {
    const newIndex = Math.max(0, selectedIndex - VISIBLE_ITEMS);
    setSelectedIndex(newIndex);
    setScrollOffset(Math.max(0, newIndex));
    setFrameIndex((prev) => {
      const idx = prev + 1;
      measureFrame(idx);
      return idx;
    });
  }, [selectedIndex, measureFrame]);

  const pageDown = useCallback(() => {
    const newIndex = Math.min(TOTAL_ITEMS - 1, selectedIndex + VISIBLE_ITEMS);
    setSelectedIndex(newIndex);
    setScrollOffset(Math.min(TOTAL_ITEMS - VISIBLE_ITEMS, Math.max(0, newIndex - VISIBLE_ITEMS + 1)));
    setFrameIndex((prev) => {
      const idx = prev + 1;
      measureFrame(idx);
      return idx;
    });
  }, [selectedIndex, measureFrame]);

  useInput((input, key) => {
    if (key.ctrl && input === 'c') {
      exit();
      return;
    }
    if (input === 'q') {
      exit();
      return;
    }
    if (key.upArrow || input === 'k') {
      scrollUp();
    } else if (key.downArrow || input === 'j') {
      scrollDown();
    } else if (key.pageUp) {
      pageUp();
    } else if (key.pageDown) {
      pageDown();
    }
  });

  const scrollPercentage = Math.round((scrollOffset / (TOTAL_ITEMS - VISIBLE_ITEMS)) * 100);

  return (
    <Box flexDirection="column" padding={1}>
      <Box marginBottom={1} justifyContent="space-between">
        <Text bold color="cyan">Scrolling List Benchmark</Text>
        <Text dimColor>
          {selectedIndex + 1}/{TOTAL_ITEMS} ({scrollPercentage}%)
        </Text>
      </Box>

      <Box
        flexDirection="column"
        borderStyle="single"
        borderColor="blue"
        height={VISIBLE_ITEMS + 2}
      >
        {visibleItems.map((item, idx) => {
          const actualIndex = scrollOffset + idx;
          const isSelected = actualIndex === selectedIndex;
          return (
            <Box key={item.id} paddingX={1}>
              <Text
                backgroundColor={isSelected ? 'blue' : undefined}
                color={isSelected ? 'white' : undefined}
              >
                {isSelected ? '▶ ' : '  '}
                {item.label.padEnd(15)} | Value: {item.value.toString().padStart(4)}
              </Text>
            </Box>
          );
        })}
      </Box>

      {/* Scrollbar indicator */}
      <Box marginTop={1}>
        <Text dimColor>
          Scroll: [{'█'.repeat(Math.floor(scrollPercentage / 5))}{'░'.repeat(20 - Math.floor(scrollPercentage / 5))}]
        </Text>
      </Box>

      <Box marginTop={1}>
        <Text dimColor>↑/↓ or j/k: scroll, PgUp/PgDn: page, q: quit</Text>
      </Box>

      <Box marginTop={1}>
        <Text dimColor>Frame: {frameIndex} | Visible items: {visibleItems.length} (virtualized)</Text>
      </Box>
    </Box>
  );
};
