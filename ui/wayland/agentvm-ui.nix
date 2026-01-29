# agentvm-ui.nix - Nix package for Oligarchy AgentVM UI
#
# A lightweight GTK4/Wayland UI for controlling AI coding agents.
# Uses native Wayland protocols for optimal performance.
#
# Usage:
#   nix-build agentvm-ui.nix
#   ./result/bin/agentvm-ui --api-url http://localhost:8000 --api-key your-key
#
# Or integrate into your NixOS configuration:
#   environment.systemPackages = [ (pkgs.callPackage ./agentvm-ui.nix {}) ];

{ lib
, python3Packages
, wrapGAppsHook4
, gobject-introspection
, gtk4
, libadwaita
, cairo
, pango
}:

python3Packages.buildPythonApplication rec {
  pname = "agentvm-ui";
  version = "1.0.0";

  src = ./.;

  # Wrapper to set up GObject introspection
  nativeBuildInputs = [
    wrapGAppsHook4
    gobject-introspection
  ];

  # GTK4 and dependencies
  buildInputs = [
    gtk4
    libadwaita
    cairo
    pango
  ];

  propagatedBuildInputs = with python3Packages; [
    pygobject3      # GTK bindings
    aiohttp         # Async HTTP client
    gbulb           # Asyncio integration with GLib
  ];

  # Wrapper to ensure GTK can find schemas
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH"
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"
    )
  '';

  # Install the Python script
  installPhase = ''
    mkdir -p $out/bin
    cp agentvm_ui.py $out/bin/agentvm-ui
    chmod +x $out/bin/agentvm-ui
  '';

  meta = with lib; {
    description = "Lightweight Wayland UI for Oligarchy AgentVM";
    homepage = "https://github.com/oligarchy/agentvm";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
