import React, { useState, useEffect, useCallback } from 'react';
import { Box, Text, useInput, useApp } from 'ink';

interface CounterProps {
  onFirstRender: () => void;
  onFrame: (frameIndex: number, frameTime: number) => void;
}

export const Counter: React.FC<CounterProps> = ({ onFirstRender, onFrame }) => {
  const [count, setCount] = useState(0);
  const [frameIndex, setFrameIndex] = useState(0);
  const { exit } = useApp();

  useEffect(() => {
    onFirstRender();
  }, [onFirstRender]);

  const handleIncrement = useCallback(() => {
    const frameStart = performance.now();
    setCount((prev) => prev + 1);
    setFrameIndex((prev) => {
      const newIndex = prev + 1;
      // Schedule measurement after React commits the update
      setTimeout(() => {
        const frameTime = performance.now() - frameStart;
        onFrame(newIndex, frameTime);
      }, 0);
      return newIndex;
    });
  }, [onFrame]);

  useInput((input, key) => {
    if (key.ctrl && input === 'c') {
      exit();
      return;
    }
    if (input === 'q') {
      exit();
      return;
    }
    // Any other key increments the counter
    handleIncrement();
  });

  return (
    <Box flexDirection="column" padding={1}>
      <Box marginBottom={1}>
        <Text bold color="cyan">Counter Benchmark</Text>
      </Box>

      <Box
        borderStyle="round"
        borderColor="green"
        paddingX={4}
        paddingY={1}
        justifyContent="center"
      >
        <Text bold>
          Count: <Text color="yellow">{count}</Text>
        </Text>
      </Box>

      <Box marginTop={1}>
        <Text dimColor>Press any key to increment, 'q' to quit</Text>
      </Box>

      <Box marginTop={1}>
        <Text dimColor>Frame: {frameIndex}</Text>
      </Box>
    </Box>
  );
};
