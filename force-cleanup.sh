#!/bin/bash

# SpaceAgent Force Cleanup Script
# Use this when normal cleanup doesn't work

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "💀 SpaceAgent Force Cleanup Script"
echo "=================================="

# Step 1: Unload launch agent
echo -e "${BLUE}Step 1: Unloading launch agent...${NC}"
launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist 2>/dev/null || true
echo -e "${GREEN}✓ Launch agent unloaded${NC}"

# Step 2: Kill all SpaceAgent processes aggressively
echo -e "${BLUE}Step 2: Force killing all SpaceAgent processes...${NC}"
RUNNING_PIDS=$(pgrep -f "SpaceAgent" || true)
if [ -n "$RUNNING_PIDS" ]; then
    echo "Found running SpaceAgent processes: $RUNNING_PIDS"
    
    # Kill each process individually
    for pid in $RUNNING_PIDS; do
        echo "Force killing PID: $pid"
        kill -9 "$pid" 2>/dev/null || true
    done
    
    sleep 2
    
    # Double-check and kill any remaining
    REMAINING_PIDS=$(pgrep -f "SpaceAgent" || true)
    if [ -n "$REMAINING_PIDS" ]; then
        echo "Still found processes: $REMAINING_PIDS"
        for pid in $REMAINING_PIDS; do
            echo "Force killing remaining PID: $pid"
            kill -9 "$pid" 2>/dev/null || true
        done
        sleep 1
    fi
    
    echo -e "${GREEN}✓ All SpaceAgent processes force killed${NC}"
else
    echo -e "${GREEN}✓ No SpaceAgent processes were running${NC}"
fi

# Step 3: Kill any hanging processes
echo -e "${BLUE}Step 3: Checking for hanging processes...${NC}"
HANGING_PIDS=$(ps aux | grep -i spaceagent | grep -v grep | awk '{print $2}' || true)
if [ -n "$HANGING_PIDS" ]; then
    echo "Found hanging processes: $HANGING_PIDS"
    for pid in $HANGING_PIDS; do
        echo "Killing hanging PID: $pid"
        kill -9 "$pid" 2>/dev/null || true
    done
    sleep 1
fi

# Step 4: Final verification
echo -e "${BLUE}Step 4: Final verification...${NC}"
FINAL_CHECK=$(pgrep -f "SpaceAgent" || true)
if [ -n "$FINAL_CHECK" ]; then
    echo -e "${RED}❌ Warning: Some SpaceAgent processes may still be running${NC}"
    echo "Remaining PIDs: $FINAL_CHECK"
    echo "You may need to restart your system or manually kill these processes"
else
    echo -e "${GREEN}✓ Force cleanup completed successfully${NC}"
    echo "No SpaceAgent processes are running"
fi

echo ""
echo "✅ Force cleanup completed!"
echo ""
echo "If processes are still hanging, try:"
echo "  sudo kill -9 <PID>  # for specific PIDs"
echo "  sudo pkill -9 -f SpaceAgent  # for all SpaceAgent processes"
