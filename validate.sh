#!/bin/bash

echo "🔍 Validating SpaceAgent Swift syntax..."

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Swift not found. Cannot validate syntax."
    exit 1
fi

# Validate each Swift file
for file in SpaceAgent/*.swift SpaceAgentTests/*.swift; do
    if [ -f "$file" ]; then
        echo "▶️ Checking $file"
        swift -frontend -parse "$file" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ $file - OK"
        else
            echo "❌ $file - Syntax errors found"
            swift -frontend -parse "$file"
        fi
    fi
done

echo ""
echo "🧪 Test structure validation:"

# Check that test files have proper XCTest imports and class structure
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

echo ""
echo "✅ Validation complete!"