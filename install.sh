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

# Step 1: Stop any running instances
echo -e "${BLUE}Step 1: Stopping any running SpaceAgent instances...${NC}"
RUNNING_PIDS=$(pgrep -f "SpaceAgent" || true)
if [ -n "$RUNNING_PIDS" ]; then
    echo "Found running SpaceAgent processes: $RUNNING_PIDS"
    echo "Stopping them..."
    pkill -f "SpaceAgent" || true
    sleep 2
    
    # Force kill if still running
    REMAINING_PIDS=$(pgrep -f "SpaceAgent" || true)
    if [ -n "$REMAINING_PIDS" ]; then
        echo "Force killing remaining processes..."
        pkill -9 -f "SpaceAgent" || true
    fi
    echo -e "${GREEN}✓ Stopped all SpaceAgent processes${NC}"
else
    echo -e "${GREEN}✓ No SpaceAgent processes were running${NC}"
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
    cp com.mtm.spaceagent.plist ~/Library/LaunchAgents/
    launchctl load ~/Library/LaunchAgents/com.mtm.spaceagent.plist
    echo -e "${GREEN}✓ Auto-start configured${NC}"
fi

# Step 6: Start the app
echo -e "${BLUE}Step 6: Starting SpaceAgent...${NC}"
echo "🚀 Launching SpaceAgent..."
open "/Applications/SpaceAgent.app"

# Wait a moment for the app to start
sleep 2

# Check if it's running
if pgrep -f "SpaceAgent" > /dev/null; then
    echo -e "${GREEN}✓ SpaceAgent is now running!${NC}"
else
    echo -e "${YELLOW}⚠️  SpaceAgent may not have started properly${NC}"
    echo "Check Console.app for any error messages"
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