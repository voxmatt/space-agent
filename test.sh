#!/bin/bash

# SpaceAgent Test Runner

set -e

echo "🧪 Running SpaceAgent Tests..."

# Build and run tests
echo "▶️ Building and running unit tests..."
xcodebuild test -project SpaceAgent.xcodeproj -scheme SpaceAgent -destination 'platform=macOS'

echo ""
echo "✅ All tests completed!"

# Optional: Run specific test classes
if [ "$1" = "space" ]; then
    echo "🚀 Running SpaceMonitor tests only..."
    xcodebuild test -project SpaceAgent.xcodeproj -scheme SpaceAgent -destination 'platform=macOS' -only-testing:SpaceAgentTests/SpaceMonitorTests
elif [ "$1" = "integration" ]; then
    echo "🔗 Running integration tests only..."
    xcodebuild test -project SpaceAgent.xcodeproj -scheme SpaceAgent -destination 'platform=macOS' -only-testing:SpaceAgentTests/IntegrationTests
fi