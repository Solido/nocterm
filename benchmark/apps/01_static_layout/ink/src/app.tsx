import React, { useEffect } from 'react';
import { Box, Text } from 'ink';

interface StaticLayoutProps {
  onFirstRender: () => void;
}

export const StaticLayout: React.FC<StaticLayoutProps> = ({ onFirstRender }) => {
  useEffect(() => {
    onFirstRender();
  }, [onFirstRender]);

  return (
    <Box flexDirection="column" width={80} height={24}>
      {/* Header */}
      <Box
        borderStyle="single"
        borderColor="blue"
        justifyContent="center"
        paddingX={1}
      >
        <Text bold color="cyan">
          Static Layout Benchmark
        </Text>
      </Box>

      {/* Separator */}
      <Box>
        <Text>{'─'.repeat(80)}</Text>
      </Box>

      {/* Main content area */}
      <Box flexDirection="row" height={18}>
        {/* Left Panel */}
        <Box
          flexDirection="column"
          width={40}
          borderStyle="single"
          borderColor="green"
          paddingX={1}
        >
          <Text bold color="green">Left Panel</Text>
          <Box marginTop={1}>
            <Text>• Item 1</Text>
          </Box>
          <Box>
            <Text>• Item 2</Text>
          </Box>
          <Box>
            <Text>• Item 3</Text>
          </Box>
          <Box marginTop={1}>
            <Text dimColor>This is a static layout test.</Text>
          </Box>
          <Box>
            <Text dimColor>No interactivity required.</Text>
          </Box>
        </Box>

        {/* Right Panel */}
        <Box
          flexDirection="column"
          width={40}
          borderStyle="single"
          borderColor="yellow"
          paddingX={1}
        >
          <Text bold color="yellow">Right Panel</Text>
          <Box marginTop={1}>
            <Text>Status: <Text color="green">Active</Text></Text>
          </Box>
          <Box>
            <Text>Mode: <Text color="cyan">Benchmark</Text></Text>
          </Box>
          <Box marginTop={1}>
            <Text dimColor>Performance metrics will be</Text>
          </Box>
          <Box>
            <Text dimColor>collected for analysis.</Text>
          </Box>
        </Box>
      </Box>

      {/* Footer */}
      <Box
        borderStyle="single"
        borderColor="magenta"
        justifyContent="center"
        paddingX={1}
      >
        <Text color="magenta">
          Press Ctrl+C to exit
        </Text>
      </Box>
    </Box>
  );
};
