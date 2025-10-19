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

# Step 1: Stop any running instances and disable launch agent
echo -e "${BLUE}Step 1: Stopping any running SpaceAgent instances...${NC}"

# First, unload the launch agent to prevent auto-restart
if [ -f ~/Library/LaunchAgents/com.mtm.spaceagent.plist ]; then
    echo "Unloading launch agent to prevent auto-restart..."
    launchctl unload ~/Library/LaunchAgents/com.mtm.spaceagent.plist 2>/dev/null || true
    sleep 1
fi

# Now kill any running processes
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
        sleep 1
    fi
    
    # Final verification
    FINAL_CHECK=$(pgrep -f "SpaceAgent" || true)
    if [ -n "$FINAL_CHECK" ]; then
        echo -e "${YELLOW}⚠️  Warning: Some SpaceAgent processes may still be running${NC}"
        echo "You may need to manually quit SpaceAgent from the menu bar"
    else
        echo -e "${GREEN}✓ Stopped all SpaceAgent processes${NC}"
    fi
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
sleep 3

# Check if it's running
if pgrep -f "SpaceAgent" > /dev/null; then
    echo -e "${GREEN}✓ SpaceAgent is now running!${NC}"
    echo "You should see the space number in your menu bar"
else
    echo -e "${YELLOW}⚠️  SpaceAgent may not have started properly${NC}"
    echo "Try manually launching it from Applications or check Console.app for errors"
    echo "You can also run: open /Applications/SpaceAgent.app"
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