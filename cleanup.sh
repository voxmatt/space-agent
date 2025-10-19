#!/bin/bash

# SpaceAgent Cleanup Script
# Use this when testing to ensure only one instance is running

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🧹 SpaceAgent Cleanup Script"
echo "============================"

# Step 1: Unload launch agent
echo -e "${BLUE}Step 1: Unloading launch agent...${NC}"
if [ -f ~/Library/LaunchAgents/com.mtm.spaceagent.plist ]; then
    launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist 2>/dev/null || true
    echo -e "${GREEN}✓ Launch agent unloaded${NC}"
else
    echo -e "${GREEN}✓ No launch agent found${NC}"
fi

# Step 2: Kill all SpaceAgent processes
echo -e "${BLUE}Step 2: Stopping all SpaceAgent processes...${NC}"
RUNNING_PIDS=$(pgrep -f "SpaceAgent" || true)
if [ -n "$RUNNING_PIDS" ]; then
    echo "Found running SpaceAgent processes: $RUNNING_PIDS"
    
    # First, try graceful termination
    echo "Attempting graceful termination..."
    pkill -TERM -f "SpaceAgent" || true
    sleep 3
    
    # Check if still running
    REMAINING_PIDS=$(pgrep -f "SpaceAgent" || true)
    if [ -n "$REMAINING_PIDS" ]; then
        echo "Processes still running, attempting force kill..."
        pkill -9 -f "SpaceAgent" || true
        sleep 2
        
        # Final check
        FINAL_PIDS=$(pgrep -f "SpaceAgent" || true)
        if [ -n "$FINAL_PIDS" ]; then
            echo "Some processes still running, attempting individual kill..."
            for pid in $FINAL_PIDS; do
                echo "Killing PID: $pid"
                kill -9 "$pid" 2>/dev/null || true
            done
            sleep 1
        fi
    fi
    
    echo -e "${GREEN}✓ All SpaceAgent processes stopped${NC}"
else
    echo -e "${GREEN}✓ No SpaceAgent processes were running${NC}"
fi

# Step 3: Verify cleanup
echo -e "${BLUE}Step 3: Verifying cleanup...${NC}"
FINAL_CHECK=$(pgrep -f "SpaceAgent" || true)
if [ -n "$FINAL_CHECK" ]; then
    echo -e "${RED}❌ Warning: Some SpaceAgent processes may still be running${NC}"
    echo "Remaining PIDs: $FINAL_CHECK"
    echo "You may need to manually quit SpaceAgent from the menu bar"
else
    echo -e "${GREEN}✓ Cleanup completed successfully${NC}"
    echo "No SpaceAgent processes are running"
fi

echo ""
echo "✅ Cleanup completed!"
echo ""
echo "To start SpaceAgent again:"
echo "  ./install.sh  # For production installation"
echo "  open build/Debug/SpaceAgent.app  # For testing"
