import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Box, Text, useInput, useApp } from 'ink';

interface Metrics {
  cpu: number;
  memory: number;
  requests: number;
}

interface Task {
  id: number;
  name: string;
  progress: number;
  speed: number; // progress increment per tick
}

interface LogEntry {
  timestamp: string;
  message: string;
  level: 'info' | 'warn' | 'error' | 'success';
}

interface DashboardProps {
  onFirstRender: () => void;
  onFrame: (frameIndex: number, frameTime: number) => void;
}

const LOG_MESSAGES = [
  { message: 'Processing request...', level: 'info' as const },
  { message: 'Cache hit for key xyz', level: 'success' as const },
  { message: 'Connection established', level: 'info' as const },
  { message: 'Query completed in 23ms', level: 'success' as const },
  { message: 'Rate limit warning', level: 'warn' as const },
  { message: 'Retrying failed request', level: 'warn' as const },
  { message: 'Database query slow', level: 'warn' as const },
  { message: 'User authenticated', level: 'success' as const },
  { message: 'File uploaded successfully', level: 'success' as const },
  { message: 'Timeout on external API', level: 'error' as const },
  { message: 'Memory threshold exceeded', level: 'error' as const },
  { message: 'Webhook delivered', level: 'info' as const },
  { message: 'Background job started', level: 'info' as const },
  { message: 'Compression completed', level: 'success' as const },
  { message: 'New session created', level: 'info' as const },
];

const MAX_LOG_ENTRIES = 8;
const TASK_COUNT = 5;

function formatTime(date: Date): string {
  return date.toTimeString().slice(0, 8);
}

function formatUptime(seconds: number): string {
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

function ProgressBar({ progress, width = 20, color = 'green' }: { progress: number; width?: number; color?: string }) {
  const filled = Math.floor((progress / 100) * width);
  const empty = width - filled;
  return (
    <Text>
      <Text color={color}>{'█'.repeat(filled)}</Text>
      <Text dimColor>{'░'.repeat(empty)}</Text>
    </Text>
  );
}

function MetricBox({ label, value, unit, color }: { label: string; value: string | number; unit?: string; color?: string }) {
  return (
    <Box paddingX={1}>
      <Text>
        {label}: <Text color={color} bold>{value}</Text>{unit ? <Text dimColor>{unit}</Text> : null}
      </Text>
    </Box>
  );
}

export const Dashboard: React.FC<DashboardProps> = ({ onFirstRender, onFrame }) => {
  const [metrics, setMetrics] = useState<Metrics>({ cpu: 45, memory: 2.1, requests: 1200 });
  const [tasks, setTasks] = useState<Task[]>(() =>
    Array.from({ length: TASK_COUNT }, (_, i) => ({
      id: i,
      name: `Task ${i + 1}`,
      progress: Math.floor(Math.random() * 50),
      speed: 1 + Math.random() * 3,
    }))
  );
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [uptimeSeconds, setUptimeSeconds] = useState(0);
  const [frameCount, setFrameCount] = useState(0);
  const [fps, setFps] = useState(0);
  const lastFrameTime = useRef(performance.now());
  const fpsHistory = useRef<number[]>([]);
  const { exit } = useApp();

  useEffect(() => {
    onFirstRender();
  }, [onFirstRender]);

  // Main animation loop
  useEffect(() => {
    const intervalId = setInterval(() => {
      const now = performance.now();
      const frameTime = now - lastFrameTime.current;
      lastFrameTime.current = now;

      // Calculate FPS
      const currentFps = 1000 / frameTime;
      fpsHistory.current.push(currentFps);
      if (fpsHistory.current.length > 10) {
        fpsHistory.current.shift();
      }
      const avgFps = fpsHistory.current.reduce((a, b) => a + b, 0) / fpsHistory.current.length;
      setFps(Math.round(avgFps));

      setFrameCount((prev) => {
        const newCount = prev + 1;
        onFrame(newCount, frameTime);
        return newCount;
      });

      // Update metrics with random fluctuations
      setMetrics((prev) => ({
        cpu: Math.max(5, Math.min(95, prev.cpu + (Math.random() - 0.5) * 10)),
        memory: Math.max(0.5, Math.min(8, prev.memory + (Math.random() - 0.5) * 0.3)),
        requests: Math.max(100, Math.min(5000, prev.requests + Math.floor((Math.random() - 0.5) * 200))),
      }));

      // Update task progress
      setTasks((prev) =>
        prev.map((task) => ({
          ...task,
          progress: task.progress >= 100 ? 0 : Math.min(100, task.progress + task.speed),
        }))
      );

      // Add random log entries
      if (Math.random() < 0.3) {
        const randomLog = LOG_MESSAGES[Math.floor(Math.random() * LOG_MESSAGES.length)];
        setLogs((prev) => {
          const newLogs = [
            ...prev,
            {
              timestamp: formatTime(new Date()),
              message: randomLog.message,
              level: randomLog.level,
            },
          ];
          return newLogs.slice(-MAX_LOG_ENTRIES);
        });
      }
    }, 100); // ~10 FPS target for dashboard updates

    return () => clearInterval(intervalId);
  }, [onFrame]);

  // Uptime counter
  useEffect(() => {
    const uptimeInterval = setInterval(() => {
      setUptimeSeconds((prev) => prev + 1);
    }, 1000);

    return () => clearInterval(uptimeInterval);
  }, []);

  useInput((input, key) => {
    if (key.ctrl && input === 'c') {
      exit();
    }
    if (input === 'q') {
      exit();
    }
  });

  const getLogColor = (level: LogEntry['level']) => {
    switch (level) {
      case 'info': return 'blue';
      case 'warn': return 'yellow';
      case 'error': return 'red';
      case 'success': return 'green';
    }
  };

  const getCpuColor = (cpu: number) => {
    if (cpu < 50) return 'green';
    if (cpu < 80) return 'yellow';
    return 'red';
  };

  return (
    <Box flexDirection="column" width={80}>
      {/* Header with metrics */}
      <Box
        borderStyle="single"
        borderColor="cyan"
        justifyContent="space-between"
        paddingX={1}
      >
        <Text bold color="cyan">Dashboard Benchmark</Text>
        <Text dimColor>FPS: {fps} | Frame: {frameCount}</Text>
      </Box>

      {/* Metrics row */}
      <Box
        borderStyle="single"
        borderColor="blue"
        justifyContent="space-around"
      >
        <MetricBox label="CPU" value={Math.round(metrics.cpu)} unit="%" color={getCpuColor(metrics.cpu)} />
        <MetricBox label="MEM" value={metrics.memory.toFixed(1)} unit="GB" color="cyan" />
        <MetricBox label="REQ" value={`${(metrics.requests / 1000).toFixed(1)}k`} unit="/s" color="magenta" />
      </Box>

      {/* Main content: Progress bars + Logs */}
      <Box flexDirection="row" height={12}>
        {/* Progress bars panel */}
        <Box
          flexDirection="column"
          width={40}
          borderStyle="single"
          borderColor="green"
          paddingX={1}
        >
          <Text bold color="green">Tasks</Text>
          {tasks.map((task) => (
            <Box key={task.id} marginTop={task.id === 0 ? 0 : 0}>
              <Text>
                <ProgressBar progress={task.progress} width={15} color={task.progress >= 100 ? 'cyan' : 'green'} />
                <Text> {task.name} </Text>
                <Text color="yellow">{Math.round(task.progress)}%</Text>
              </Text>
            </Box>
          ))}
        </Box>

        {/* Log panel */}
        <Box
          flexDirection="column"
          width={40}
          borderStyle="single"
          borderColor="yellow"
          paddingX={1}
        >
          <Text bold color="yellow">Activity Log</Text>
          {logs.length === 0 ? (
            <Text dimColor>Waiting for events...</Text>
          ) : (
            logs.map((log, idx) => (
              <Box key={idx}>
                <Text>
                  <Text dimColor>[{log.timestamp}]</Text>{' '}
                  <Text color={getLogColor(log.level)}>
                    {log.message.slice(0, 25)}
                  </Text>
                </Text>
              </Box>
            ))
          )}
        </Box>
      </Box>

      {/* Footer with status */}
      <Box
        borderStyle="single"
        borderColor="magenta"
        justifyContent="space-between"
        paddingX={1}
      >
        <Text>
          Status: <Text color="green" bold>Running</Text> for {formatUptime(uptimeSeconds)}
        </Text>
        <Text dimColor>Press 'q' to quit</Text>
      </Box>
    </Box>
  );
};
