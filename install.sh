#!/bin/bash

# SpaceAgent Installation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "📱 SpaceAgent Installation Script"
echo "================================="

# Step 1: Force cleanup all SpaceAgent instances and launch agent
echo -e "${BLUE}Step 1: Force cleaning all SpaceAgent instances...${NC}"

# Unload launch agent first
echo "Unloading launch agent..."
launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist 2>/dev/null || true
echo -e "${GREEN}✓ Launch agent unloaded${NC}"

# Step 1.1: Try graceful termination first
echo -e "${BLUE}Step 1.1: Attempting graceful termination...${NC}"
RUNNING_PIDS=$(pgrep -f "SpaceAgent" || true)
if [ -n "$RUNNING_PIDS" ]; then
    echo "Found SpaceAgent processes: $RUNNING_PIDS"
    for pid in $RUNNING_PIDS; do
        echo "Sending TERM signal to PID: $pid"
        kill -TERM "$pid" 2>/dev/null || true
    done
    
    # Wait a moment for graceful shutdown
    sleep 2
    
    # Check if still running
    REMAINING_PIDS=$(pgrep -f "SpaceAgent" || true)
    if [ -n "$REMAINING_PIDS" ]; then
        echo -e "${YELLOW}⚠️  Graceful termination failed, processes still running: $REMAINING_PIDS${NC}"
    else
        echo -e "${GREEN}✓ Graceful termination successful${NC}"
    fi
else
    echo -e "${GREEN}✓ No SpaceAgent processes found${NC}"
fi

# Step 1.2: Force kill with SIGKILL
echo -e "${BLUE}Step 1.2: Force killing with SIGKILL...${NC}"
REMAINING_PIDS=$(pgrep -f "SpaceAgent" || true)
if [ -n "$REMAINING_PIDS" ]; then
    for pid in $REMAINING_PIDS; do
        echo "Force killing PID: $pid"
        kill -9 "$pid" 2>/dev/null || true
    done
    
    sleep 1
    
    # Check again
    STILL_RUNNING=$(pgrep -f "SpaceAgent" || true)
    if [ -n "$STILL_RUNNING" ]; then
        echo -e "${YELLOW}⚠️  Some processes still running after SIGKILL: $STILL_RUNNING${NC}"
    else
        echo -e "${GREEN}✓ Force kill successful${NC}"
    fi
fi

# Step 1.3: Use pkill as backup
echo -e "${BLUE}Step 1.3: Using pkill as backup...${NC}"
pkill -9 -f "SpaceAgent" 2>/dev/null || true
sleep 1

# Step 1.4: Check for any remaining processes
echo -e "${BLUE}Step 1.4: Final verification...${NC}"
FINAL_CHECK=$(pgrep -f "SpaceAgent" || true)
if [ -n "$FINAL_CHECK" ]; then
    echo -e "${RED}❌ Error: Failed to stop all SpaceAgent processes. PIDs: $FINAL_CHECK${NC}"
    echo "These processes may be in an uninterruptible state (D state)"
    echo "You may need to restart your system to clear them"
    exit 1
else
    echo -e "${GREEN}✅ All SpaceAgent processes successfully terminated${NC}"
fi

# Step 2: Remove old version
echo -e "${BLUE}Step 2: Removing old SpaceAgent from Applications...${NC}"
if [ -d "/Applications/SpaceAgent.app" ]; then
    echo "Removing existing SpaceAgent.app from Applications..."
    sudo rm -rf "/Applications/SpaceAgent.app"
    echo -e "${GREEN}✓ Removed old SpaceAgent.app${NC}"
else
    echo -e "${GREEN}✓ No existing SpaceAgent.app found in Applications${NC}"
fi

# Step 3: Build the application
echo -e "${BLUE}Step 3: Building SpaceAgent...${NC}"
echo "🔨 Building SpaceAgent..."
xcodebuild -project SpaceAgent.xcodeproj -target SpaceAgent -configuration Release build

# Verify build succeeded
if [ ! -d "build/Release/SpaceAgent.app" ]; then
    echo -e "${RED}❌ Error: Build failed - SpaceAgent.app not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build completed successfully${NC}"

# Step 4: Copy to Applications folder
echo -e "${BLUE}Step 4: Installing to /Applications...${NC}"
echo "📂 Installing to /Applications..."
sudo cp -R build/Release/SpaceAgent.app /Applications/
echo -e "${GREEN}✓ Installed SpaceAgent.app to Applications${NC}"

# Step 5: Install launch agent
echo -e "${BLUE}Step 5: Setting up auto-start...${NC}"
echo "🚀 Setting up auto-start..."

# Check if plist file exists
if [ ! -f "com.mtm.spaceagent.plist" ]; then
    echo -e "${YELLOW}⚠️  Warning: com.mtm.spaceagent.plist not found, skipping auto-start setup${NC}"
    echo "You can set up auto-start manually later"
else
    # Unload any existing launch agent first
    launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist 2>/dev/null || true
    
    # Copy and load the new one
    cp com.mtm.spaceagent.plist ~/Library/LaunchAgents/
    launchctl load ~/Library/LaunchAgents/com.mtm.spaceagent.plist
    echo -e "${GREEN}✓ Auto-start configured${NC}"
fi

# Step 6: Verify installation
echo -e "${BLUE}Step 6: Verifying installation...${NC}"

# Wait a moment for the launch agent to start the app
echo "⏳ Waiting for SpaceAgent to start via launch agent..."
sleep 3

# Check if it's running and verify only one instance
RUNNING_COUNT=$(pgrep -f "SpaceAgent" | wc -l)
if [ "$RUNNING_COUNT" -gt 0 ]; then
    if [ "$RUNNING_COUNT" -eq 1 ]; then
        echo -e "${GREEN}✓ SpaceAgent is now running! (1 instance)${NC}"
        echo "You should see the space number in your menu bar"
        echo "The app will automatically start on system boot via the launch agent"
    else
        echo -e "${YELLOW}⚠️  Warning: Multiple SpaceAgent instances detected ($RUNNING_COUNT)${NC}"
        echo "This may cause issues. The force cleanup should have prevented this."
        pgrep -f "SpaceAgent" | xargs ps -p
    fi
else
    echo -e "${YELLOW}⚠️  SpaceAgent may not have started properly${NC}"
    echo "Check Console.app for any error messages"
    echo "You can manually launch it with: open /Applications/SpaceAgent.app"
fi

echo ""
echo "✅ SpaceAgent installed successfully!"
echo ""
echo "SpaceAgent is now monitoring your spaces and will display the current space number in the menu bar."
echo ""
echo "To uninstall:"
echo "  launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist"
echo "  rm ~/Library/LaunchAgents/com.mtm.spaceagent.plist"
echo "  sudo rm -rf /Applications/SpaceAgent.app"