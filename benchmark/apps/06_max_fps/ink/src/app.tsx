import React, { useState, useEffect, useRef } from 'react';
import { Box, Text } from 'ink';
import * as fs from 'fs';

interface FrameStats {
  description: string;
  unit: string;
  samples: number;
  mean: number;
  median: number;
  min: number;
  max: number;
  p95: number;
  p99: number;
}

function computeStats(times: number[], description: string): FrameStats {
  if (times.length === 0) {
    return { description, unit: 'microseconds', samples: 0, mean: 0, median: 0, min: 0, max: 0, p95: 0, p99: 0 };
  }

  const sorted = [...times].sort((a, b) => a - b);
  const sum = sorted.reduce((a, b) => a + b, 0);
  const mean = sum / sorted.length;
  const median = sorted[Math.floor(sorted.length / 2)];
  const min = sorted[0];
  const max = sorted[sorted.length - 1];
  const p95 = sorted[Math.floor(sorted.length * 0.95)];
  const p99 = sorted[Math.floor(sorted.length * 0.99)];

  return {
    description,
    unit: 'microseconds',
    samples: sorted.length,
    mean: Math.round(mean),
    median,
    min,
    max,
    p95,
    p99,
  };
}

export const App: React.FC = () => {
  const [counter, setCounter] = useState(0);
  const [frameCount, setFrameCount] = useState(0);
  const [elapsedMs, setElapsedMs] = useState(0);
  const [currentFps, setCurrentFps] = useState('0');
  const [avgFrameTime, setAvgFrameTime] = useState('0');

  const frameTimesRef = useRef<number[]>([]);
  const lastFrameTimeRef = useRef<number>(0);
  const startTimeRef = useRef<number>(0);
  const runningRef = useRef(true);

  useEffect(() => {
    startTimeRef.current = performance.now();
    lastFrameTimeRef.current = startTimeRef.current;

    const runFrame = () => {
      if (!runningRef.current) return;

      const now = performance.now();
      const elapsed = now - startTimeRef.current;

      // Stop after 3 seconds (matching Nocterm)
      if (elapsed > 3000) {
        runningRef.current = false;

        // Calculate results
        const fps = frameTimesRef.current.length / (elapsed / 1000);
        const result = {
          framework: 'ink',
          test: 'frame_time',
          durationMs: Math.round(elapsed),
          frameCount: frameTimesRef.current.length,
          fps: Math.round(fps),
          totalFrameTime: computeStats(frameTimesRef.current, 'Total frame time (state change to render complete)'),
        };

        // Write to file
        fs.writeFileSync('/tmp/ink_frame_time_results.json', JSON.stringify(result, null, 2));

        setTimeout(() => process.exit(0), 100);
        return;
      }

      // Record frame time (time since last frame)
      const frameTime = (now - lastFrameTimeRef.current) * 1000; // Convert to microseconds
      frameTimesRef.current.push(Math.round(frameTime));
      lastFrameTimeRef.current = now;

      // Update display values
      const frames = frameTimesRef.current.length;
      setFrameCount(frames);
      setElapsedMs(Math.round(elapsed));
      setCurrentFps((frames / (elapsed / 1000)).toFixed(0));

      if (frames > 0) {
        const sum = frameTimesRef.current.reduce((a, b) => a + b, 0);
        setAvgFrameTime((sum / frames).toFixed(0));
      }

      // Trigger next frame via state update
      setCounter(c => c + 1);

      // Schedule next iteration immediately
      setImmediate(runFrame);
    };

    // Start the benchmark loop
    setImmediate(runFrame);

    return () => {
      runningRef.current = false;
    };
  }, []);

  return (
    <Box flexDirection="column" alignItems="center" padding={2} borderStyle="round">
      <Text bold>Ink Frame Time Benchmark</Text>
      <Text> </Text>
      <Text>Frames: {frameCount} | FPS: {currentFps}</Text>
      <Text>Avg: {avgFrameTime}µs</Text>
      <Text>Counter: {counter}</Text>
      <Text> </Text>
      <Text color="gray">3 seconds, max speed</Text>
    </Box>
  );
};
