# shell.nix - Development environment for AgentVM UI
#
# Quick development setup without full system integration.
# Run: nix-shell
# Then: ./test-ui.sh

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "agentvm-ui-dev";
  
  buildInputs = with pkgs; [
    # GTK4 and Wayland
    gtk4
    libadwaita
    gobject-introspection
    
    # Graphics libraries
    cairo
    pango
    
    # Python environment
    python3
    python3Packages.pygobject3
    python3Packages.pycairo
    python3Packages.aiohttp
    python3Packages.gbulb
    
    # Development tools
    python3Packages.ipython
    python3Packages.black
    python3Packages.pylint
    
    # Testing utilities
    curl
    jq
  ];
  
  shellHook = ''
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║      AgentVM UI Development Environment                  ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Quick start:"
    echo "  ./test-ui.sh                    # Launch UI with defaults"
    echo ""
    echo "Development:"
    echo "  python3 agentvm_ui.py           # Run directly"
    echo "  black agentvm_ui.py             # Format code"
    echo "  pylint agentvm_ui.py            # Lint code"
    echo ""
    echo "Testing:"
    echo "  curl http://localhost:8000/health  # Check API"
    echo ""
    echo "Environment variables:"
    echo "  AGENT_VM_URL       - API endpoint (default: http://localhost:8000)"
    echo "  AGENT_VM_API_KEY   - API key (default: change-this-in-production-2026)"
    echo ""
    
    # Set up GObject introspection paths
    export GI_TYPELIB_PATH="$GI_TYPELIB_PATH:${pkgs.gtk4}/lib/girepository-1.0"
    export GI_TYPELIB_PATH="$GI_TYPELIB_PATH:${pkgs.libadwaita}/lib/girepository-1.0"
    
    # Enable GTK debugging
    export G_MESSAGES_DEBUG=all
    export GTK_DEBUG=interactive  # Press Ctrl+Shift+D in UI for inspector
    
    # Set theme
    export GTK_THEME=Adwaita:dark
  '';
}
