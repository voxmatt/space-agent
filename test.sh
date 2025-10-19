#!/bin/bash

# SpaceAgent Test Runner

set -e

echo "🧪 Running SpaceAgent Tests..."

# Step 1: Syntax validation (if Swift is available)
if command -v swift &> /dev/null; then
    echo "🔍 Validating Swift syntax..."
    for file in SpaceAgent/*.swift SpaceAgentTests/*.swift; do
        if [ -f "$file" ]; then
            echo "▶️ Checking $file"
            if swift -frontend -parse "$file" > /dev/null 2>&1; then
                echo "✅ $file - OK"
            else
                echo "❌ $file - Syntax errors found"
                swift -frontend -parse "$file"
                exit 1
            fi
        fi
    done
    echo "✅ Syntax validation passed"
    echo ""
else
    echo "⚠️ Swift not found, skipping syntax validation"
    echo ""
fi

# Step 2: Test structure validation
echo "🧪 Validating test structure..."
for test_file in SpaceAgentTests/*.swift; do
    if [ -f "$test_file" ]; then
        echo "▶️ Validating $test_file structure"
        
        if grep -q "import XCTest" "$test_file"; then
            echo "  ✅ Has XCTest import"
        else
            echo "  ❌ Missing XCTest import"
        fi
        
        if grep -q "@testable import SpaceAgent" "$test_file"; then
            echo "  ✅ Has @testable import"
        else
            echo "  ❌ Missing @testable import"
        fi
        
        if grep -q ": XCTestCase" "$test_file"; then
            echo "  ✅ Has XCTestCase class"
        else
            echo "  ❌ No XCTestCase class found"
        fi
        
        test_methods=$(grep -c "func test" "$test_file" || echo "0")
        echo "  📊 Test methods found: $test_methods"
    fi
done
echo "✅ Test structure validation complete"
echo ""

# Step 3: Run actual tests
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