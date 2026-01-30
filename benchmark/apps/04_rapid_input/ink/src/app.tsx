import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Box, Text, useInput, useApp } from 'ink';

interface KeypressEvent {
  key: string;
  timestamp: number;
  renderTime?: number;
}

interface RapidInputProps {
  onFirstRender: () => void;
  onKeypress: (frameIndex: number, latencyMs: number) => void;
}

export const RapidInput: React.FC<RapidInputProps> = ({ onFirstRender, onKeypress }) => {
  const [text, setText] = useState('');
  const [cursorPos, setCursorPos] = useState(0);
  const [keypressCount, setKeypressCount] = useState(0);
  const [lastLatency, setLastLatency] = useState<number | null>(null);
  const [avgLatency, setAvgLatency] = useState<number | null>(null);
  const keypressTimestamp = useRef<number | null>(null);
  const latencies = useRef<number[]>([]);
  const { exit } = useApp();

  useEffect(() => {
    onFirstRender();
  }, [onFirstRender]);

  // Measure render latency after state updates
  useEffect(() => {
    if (keypressTimestamp.current !== null) {
      const renderTime = performance.now();
      const latency = renderTime - keypressTimestamp.current;
      keypressTimestamp.current = null;

      setLastLatency(latency);
      latencies.current.push(latency);
      setAvgLatency(
        latencies.current.reduce((a, b) => a + b, 0) / latencies.current.length
      );
      onKeypress(latencies.current.length, latency);
    }
  }, [text, cursorPos, onKeypress]);

  const handleKeypress = useCallback((input: string, key: { backspace?: boolean; delete?: boolean; leftArrow?: boolean; rightArrow?: boolean; return?: boolean; ctrl?: boolean; escape?: boolean }) => {
    keypressTimestamp.current = performance.now();
    setKeypressCount((prev) => prev + 1);

    if (key.backspace) {
      if (cursorPos > 0) {
        setText((prev) => prev.slice(0, cursorPos - 1) + prev.slice(cursorPos));
        setCursorPos((prev) => prev - 1);
      }
    } else if (key.delete) {
      if (cursorPos < text.length) {
        setText((prev) => prev.slice(0, cursorPos) + prev.slice(cursorPos + 1));
      }
    } else if (key.leftArrow) {
      setCursorPos((prev) => Math.max(0, prev - 1));
    } else if (key.rightArrow) {
      setCursorPos((prev) => Math.min(text.length, prev + 1));
    } else if (key.return) {
      // Clear input on Enter
      setText('');
      setCursorPos(0);
    } else if (input && !key.ctrl && input.length === 1 && input.charCodeAt(0) >= 32) {
      // Insert printable character at cursor position
      setText((prev) => prev.slice(0, cursorPos) + input + prev.slice(cursorPos));
      setCursorPos((prev) => prev + 1);
    }
  }, [text, cursorPos]);

  useInput((input, key) => {
    if (key.ctrl && input === 'c') {
      exit();
      return;
    }
    if (key.escape) {
      exit();
      return;
    }
    handleKeypress(input, key);
  });

  // Render text with cursor
  const renderTextWithCursor = () => {
    const before = text.slice(0, cursorPos);
    const cursor = text[cursorPos] ?? ' ';
    const after = text.slice(cursorPos + 1);

    return (
      <Text>
        {before}
        <Text backgroundColor="white" color="black">{cursor}</Text>
        {after}
      </Text>
    );
  };

  return (
    <Box flexDirection="column" padding={1}>
      <Box marginBottom={1}>
        <Text bold color="cyan">Rapid Input Benchmark</Text>
      </Box>

      <Box marginBottom={1}>
        <Text dimColor>Type as fast as you can! Measures keypress-to-render latency.</Text>
      </Box>

      {/* Input field */}
      <Box
        borderStyle="single"
        borderColor="green"
        paddingX={1}
        paddingY={0}
        minHeight={3}
      >
        <Box>
          <Text color="green">➤ </Text>
          {renderTextWithCursor()}
        </Box>
      </Box>

      {/* Statistics */}
      <Box marginTop={1} flexDirection="column">
        <Box>
          <Text>Keypresses: <Text color="yellow">{keypressCount}</Text></Text>
        </Box>
        <Box>
          <Text>Characters: <Text color="yellow">{text.length}</Text></Text>
        </Box>
        <Box>
          <Text>
            Last latency:{' '}
            <Text color={lastLatency && lastLatency < 16 ? 'green' : lastLatency && lastLatency < 33 ? 'yellow' : 'red'}>
              {lastLatency !== null ? `${lastLatency.toFixed(2)}ms` : '-'}
            </Text>
          </Text>
        </Box>
        <Box>
          <Text>
            Avg latency:{' '}
            <Text color={avgLatency && avgLatency < 16 ? 'green' : avgLatency && avgLatency < 33 ? 'yellow' : 'red'}>
              {avgLatency !== null ? `${avgLatency.toFixed(2)}ms` : '-'}
            </Text>
          </Text>
        </Box>
      </Box>

      {/* Latency indicator */}
      <Box marginTop={1}>
        <Text dimColor>
          Latency: [
          {lastLatency !== null ? (
            <>
              <Text color="green">{'█'.repeat(Math.min(20, Math.max(1, Math.floor(20 - lastLatency / 2))))}</Text>
              <Text color="red">{'░'.repeat(Math.max(0, 20 - Math.min(20, Math.max(1, Math.floor(20 - lastLatency / 2)))))}</Text>
            </>
          ) : (
            '░'.repeat(20)
          )}
          ] {lastLatency !== null && lastLatency < 16 ? '60fps+' : lastLatency !== null && lastLatency < 33 ? '30fps+' : lastLatency !== null ? '<30fps' : ''}
        </Text>
      </Box>

      <Box marginTop={1}>
        <Text dimColor>←/→: move cursor, Backspace: delete, Enter: clear, Esc: quit</Text>
      </Box>
    </Box>
  );
};
