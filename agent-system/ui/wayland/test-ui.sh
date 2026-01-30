#!/usr/bin/env bash
# test-ui.sh - Quick test launcher for AgentVM UI
#
# This script sets up a minimal environment to test the UI without
# full NixOS integration. Useful for development and testing.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Oligarchy AgentVM UI - Test Launcher${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Check Dependencies
# ═══════════════════════════════════════════════════════════════════════════

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ $1 not found${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 found${NC}"
        return 0
    fi
}

echo "Checking dependencies..."
DEPS_OK=true

check_command python3 || DEPS_OK=false
check_command pkg-config || DEPS_OK=false

# Check Python packages
echo ""
echo "Checking Python packages..."

check_python_package() {
    if python3 -c "import $1" 2>/dev/null; then
        echo -e "${GREEN}✓ $1 available${NC}"
        return 0
    else
        echo -e "${RED}✗ $1 missing${NC}"
        return 1
    fi
}

check_python_package gi || DEPS_OK=false
check_python_package cairo || DEPS_OK=false
check_python_package aiohttp || DEPS_OK=false

if [ "$DEPS_OK" = false ]; then
    echo ""
    echo -e "${RED}Missing dependencies!${NC}"
    echo ""
    echo "To install with Nix:"
    echo "  nix-shell -p python3 python3Packages.pygobject3 \\"
    echo "               python3Packages.aiohttp python3Packages.gbulb \\"
    echo "               gtk4 libadwaita gobject-introspection"
    echo ""
    echo "Or use the included Nix package:"
    echo "  nix-build agentvm-ui.nix"
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}All dependencies satisfied!${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

API_URL="${AGENT_VM_URL:-http://localhost:8000}"
API_KEY="${AGENT_VM_API_KEY:-change-this-in-production-2026}"

echo "Configuration:"
echo "  API URL: $API_URL"
echo "  API Key: ${API_KEY:0:10}..."
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Health Check
# ═══════════════════════════════════════════════════════════════════════════

echo "Checking AgentVM API connection..."

if curl -s -f -H "X-API-Key: $API_KEY" "$API_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API is reachable${NC}"
    HEALTH=$(curl -s -H "X-API-Key: $API_KEY" "$API_URL/health")
    echo "  Status: $HEALTH"
else
    echo -e "${YELLOW}⚠ API not reachable at $API_URL${NC}"
    echo ""
    echo "Make sure AgentVM is running:"
    echo "  nix run .#run"
    echo ""
    echo "Or start the API manually:"
    echo "  uvicorn main:app --port 8000"
    echo ""
    echo -e "${YELLOW}Continuing anyway (UI will show connection error)...${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Launch UI
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}Launching UI...${NC}"
echo ""

# Set GTK settings for better performance
export GTK_THEME=Adwaita:dark
export GTK_CSD=0  # Disable client-side decorations for testing

# Ensure GObject introspection can find typelibs
if [ -n "${NIX_PROFILES:-}" ]; then
    export GI_TYPELIB_PATH="$NIX_PROFILES/lib/girepository-1.0"
fi

# Launch with arguments
exec python3 agentvm_ui.py \
    --api-url "$API_URL" \
    --api-key "$API_KEY" \
    "$@"
