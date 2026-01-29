#!/usr/bin/env bash
# install-godot-plugin.sh - Install AgentVM plugin to Godot project
#
# Usage:
#   ./install-godot-plugin.sh /path/to/godot/project
#   ./install-godot-plugin.sh  # Uses current directory

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Oligarchy AgentVM - Godot Plugin Installer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Determine target project
# ═══════════════════════════════════════════════════════════════════════════

TARGET_DIR="${1:-.}"
TARGET_DIR=$(realpath "$TARGET_DIR")

echo "Target project: $TARGET_DIR"
echo ""

# Check if it's a Godot project
if [ ! -f "$TARGET_DIR/project.godot" ]; then
    echo -e "${RED}✗ Not a Godot project (project.godot not found)${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 /path/to/godot/project"
    echo "  $0  # Uses current directory"
    exit 1
fi

echo -e "${GREEN}✓ Found Godot project${NC}"

# ═══════════════════════════════════════════════════════════════════════════
# Check plugin directory
# ═══════════════════════════════════════════════════════════════════════════

PLUGIN_DIR="$TARGET_DIR/addons/agentvm"

if [ -d "$PLUGIN_DIR" ]; then
    echo -e "${YELLOW}⚠ Plugin directory already exists${NC}"
    echo ""
    read -p "Overwrite existing plugin? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    rm -rf "$PLUGIN_DIR"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Create directory structure
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "Creating plugin directory structure..."

mkdir -p "$PLUGIN_DIR/core"
mkdir -p "$PLUGIN_DIR/ui"

# ═══════════════════════════════════════════════════════════════════════════
# Copy plugin files
# ═══════════════════════════════════════════════════════════════════════════

echo "Copying plugin files..."

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy files
cp "$SCRIPT_DIR/plugin.cfg" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/plugin.gd" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/config.ini" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/agent_manager.gd" "$PLUGIN_DIR/core/"
cp "$SCRIPT_DIR/agent_dock.gd" "$PLUGIN_DIR/ui/"
cp "$SCRIPT_DIR/agent_dock.tscn" "$PLUGIN_DIR/ui/"
cp "$SCRIPT_DIR/bottom_panel.gd" "$PLUGIN_DIR/ui/"
cp "$SCRIPT_DIR/bottom_panel.tscn" "$PLUGIN_DIR/ui/"

echo -e "${GREEN}✓ Plugin files copied${NC}"

# ═══════════════════════════════════════════════════════════════════════════
# Configure plugin
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "Configuration:"
echo ""

# Get API URL
read -p "AgentVM API URL [http://localhost:8000]: " API_URL
API_URL=${API_URL:-http://localhost:8000}

# Get API key
read -p "AgentVM API Key [change-this-in-production-2026]: " API_KEY
API_KEY=${API_KEY:-change-this-in-production-2026}

# Get default agent
echo "Default agent:"
echo "  1) aider (recommended)"
echo "  2) opencode"
echo "  3) claude"
read -p "Select [1]: " AGENT_CHOICE
AGENT_CHOICE=${AGENT_CHOICE:-1}

case $AGENT_CHOICE in
    1) DEFAULT_AGENT="aider" ;;
    2) DEFAULT_AGENT="opencode" ;;
    3) DEFAULT_AGENT="claude" ;;
    *) DEFAULT_AGENT="aider" ;;
esac

# Update config.ini
cat > "$PLUGIN_DIR/config.ini" << EOF
[api]
url = $API_URL
key = $API_KEY

[agent]
default = $DEFAULT_AGENT
timeout = 600

[ui]
auto_show_output = true
history_limit = 100
EOF

echo -e "${GREEN}✓ Configuration saved${NC}"

# ═══════════════════════════════════════════════════════════════════════════
# Test connection
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "Testing AgentVM connection..."

if curl -s -f -H "X-API-Key: $API_KEY" "$API_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Successfully connected to AgentVM${NC}"
    HEALTH=$(curl -s -H "X-API-Key: $API_KEY" "$API_URL/health")
    echo "  Status: $HEALTH"
else
    echo -e "${YELLOW}⚠ Could not connect to AgentVM${NC}"
    echo ""
    echo "Make sure AgentVM is running:"
    echo "  nix run .#run"
    echo ""
    echo "You can update the configuration later in:"
    echo "  $PLUGIN_DIR/config.ini"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Final instructions
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Installation complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Open your project in Godot"
echo "2. Go to: Project → Project Settings → Plugins"
echo "3. Enable 'Oligarchy AgentVM'"
echo "4. Look for the AgentVM panel in the editor"
echo ""
echo "Documentation:"
echo "  Plugin README: $PLUGIN_DIR/../GODOT-README.md"
echo "  Configuration: $PLUGIN_DIR/config.ini"
echo ""
echo "Quick test:"
echo '  1. Type in prompt: "Add a simple print statement"'
echo "  2. Click 'Run Agent'"
echo "  3. Check output in bottom panel"
echo ""
echo -e "${BLUE}Happy AI-assisted game development!${NC}"
