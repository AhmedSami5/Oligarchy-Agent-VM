# Oligarchy AgentVM

**Production-Ready NixOS VM for AI-Assisted Development**

A lightweight, secure, and API-driven development environment optimized for AI coding agents. Built with NixOS for complete reproducibility and isolation.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![NixOS](https://img.shields.io/badge/NixOS-25.05-blue.svg)](https://nixos.org)
[![Godot](https://img.shields.io/badge/Godot-4.2+-green.svg)](https://godotengine.org)

## Overview

Oligarchy AgentVM provides a sandboxed environment where AI coding agents (aider, opencode, claude-code) can safely modify code, with full programmatic control via a REST API. Designed for developers who need reproducible, isolated environments with real-time integration capabilities.

### Key Features

- **Pre-installed AI Agents**: aider, opencode, claude-code ready to use
- **FastAPI Controller**: REST API for programmatic agent orchestration
- **Auto Tmux Sessions**: Unique tmux session per SSH connection
- **Session Recording**: Optional asciinema recording with auto-cleanup
- **Virtiofs Sharing**: Read-only host directory access
- **CPU Pinning**: Isolate cores for DSP/real-time workloads
- **Neovim + LSP**: Fully configured with nixd, Treesitter, Telescope
- **Security Hardened**: Systemd sandboxing, secrets management support
- **Multiple UIs**: GTK4 Wayland native UI and Godot/Redot plugin
- **Reproducible**: NixOS flake ensures identical builds

## Quick Start

### Prerequisites

- NixOS or any system with Nix package manager (with flakes enabled)
- QEMU/KVM for virtualization
- Approximately 10GB disk space for VM image

### Installation

```bash
# Clone the repository
git clone https://github.com/ALH477/Oligarchy-Agent-VM.git
cd Oligarchy-Agent-VM

# Build the VM image
nix build .#agent-vm-qcow2

# Launch the VM with automatic port forwarding
nix run .#run

# In a separate terminal, connect via SSH
ssh user@127.0.0.1 -p 2222
# Default password: "agent" (change on first login)

# Access API documentation
curl http://127.0.0.1:8000/docs
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Host System                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Framework Laptop (Core 0: DSP Work)                   │ │
│  │  /home/you/projects  ←──────────────────┐              │ │
│  └────────────────────────────────────────────────────────┘ │
│                         │ virtiofs (ro)                      │
└─────────────────────────┼───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    Oligarchy AgentVM                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Cores 1-7 (isolated via isolcpus)                     │ │
│  │  8GB RAM                                                │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │ SSH Server   │  │ FastAPI      │  │ AI Agents    │ │ │
│  │  │ Port 22      │  │ Port 8000    │  │ aider        │ │ │
│  │  │              │  │              │  │ opencode     │ │ │
│  │  │              │  │              │  │ claude-code  │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  │                                                          │ │
│  │  /mnt/host-projects (read-only mount)                   │ │
│  │  /home/user/ssh-recordings (asciinema casts)            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │                    │
         │ SSH :2222          │ HTTP :8000
         ▼                    ▼
    Terminal              Custom UI
```

## Repository Structure

```
Oligarchy-Agent-VM/
├── flake.nix                    # Main NixOS flake with VM configuration
├── flake.lock                   # Locked dependencies
├── README.md                    # This file
├── LICENSE                      # Project license
│
├── docs/
│   ├── EXAMPLES.md              # Usage examples and workflows
│   └── TROUBLESHOOTING.md       # Common issues and solutions
│
├── ui/
│   ├── wayland/
│   │   ├── agentvm_ui.py        # GTK4 Wayland UI
│   │   ├── agentvm-ui.nix       # Nix package for UI
│   │   ├── shell.nix            # Development environment
│   │   ├── test-ui.sh           # Quick test launcher
│   │   ├── ui-mockup.html       # Visual mockup
│   │   └── UI-README.md         # UI documentation
│   │
│   └── godot/
│       ├── plugin.cfg           # Godot plugin metadata
│       ├── plugin.gd            # Main plugin script
│       ├── config.ini           # Default configuration
│       ├── core/
│       │   └── agent_manager.gd # API communication manager
│       ├── ui/
│       │   ├── agent_dock.gd    # Main dock panel
│       │   ├── agent_dock.tscn  # Dock scene
│       │   ├── bottom_panel.gd  # Output panel
│       │   └── bottom_panel.tscn # Output scene
│       ├── install-godot-plugin.sh  # Automated installer
│       ├── GODOT-README.md      # Plugin documentation
│       └── PLUGIN-STRUCTURE.md  # Directory guide
│
└── tools/
    └── agent_vm_client.py       # Python client library
```

## Configuration

### Basic Configuration

Edit the VM configuration in `flake.nix`:

```nix
oligarchy.agent-vm = {
  enable = true;
  
  # Choose deployment mode
  deploymentMode = "headless-ssh";  # or "minimal-ssh-only" or "full-gui"
  
  # Resource allocation
  cpuCores = 6;
  memoryMB = 8192;
  
  # CPU isolation (important for DSP work)
  reservedCores = "1-7";  # Cores for VM (0 reserved for host)
  
  # Host directory sharing
  hostSharePath = "/home/you/projects";
};
```

### Security Configuration

**Development:**
```nix
oligarchy.agent-vm = {
  apiKeyFallback = "my-dev-key-123";
};
```

**Production (recommended):**
```nix
oligarchy.agent-vm = {
  apiKeyFile = /run/secrets/agent-api-key;  # Use sops-nix or agenix
};
```

### Deployment Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `headless-ssh` | SSH + Docker + Full tooling | Recommended for most users |
| `minimal-ssh-only` | SSH + Podman only | Lowest resource usage |
| `full-gui` | Wayland GUI + SSH + Docker | Visual debugging, GUI tools |

## API Usage

### Authentication

All API requests require the `X-API-Key` header:

```bash
export API_KEY="your-api-key-here"
```

### Health Check

```bash
curl http://localhost:8000/health
```

### Run an Agent

```bash
curl -X POST http://localhost:8000/agent/run \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "aider",
    "prompt": "Add error handling to the authentication module",
    "repo_path": "/mnt/host-projects/my-app",
    "timeout": 600
  }'
```

### Available Agents

- **aider**: Multi-file editing with Claude 3.5 Sonnet
- **opencode**: Autonomous coding agent
- **claude**: Claude Code CLI

### Response Format

```json
{
  "success": true,
  "stdout": "Modified 3 files...",
  "stderr": "",
  "returncode": 0
}
```

### Interactive API Documentation

Visit http://localhost:8000/docs for full Swagger UI documentation.

## User Interfaces

### Python Client Library

```python
from agent_vm_client import AgentVMClient

client = AgentVMClient(api_key="your-key")
result = client.run_aider("Add error handling to the API endpoints")

if result.success:
    print(result.stdout)
```

See `tools/agent_vm_client.py` for complete API.

### GTK4 Wayland UI

Lightweight native interface with brutalist industrial aesthetic.

```bash
# Build UI
nix build .#agentvm-ui

# Run
./result/bin/agentvm-ui --api-url http://localhost:8000 --api-key your-key
```

Memory footprint: ~180MB (vs 1200MB+ for Electron)

See `ui/wayland/UI-README.md` for details.

### Godot/Redot Plugin

Editor integration for AI-assisted game development.

```bash
# Install to Godot project
cd ui/godot
./install-godot-plugin.sh /path/to/your/godot/project
```

Then enable in Project Settings → Plugins.

See `ui/godot/GODOT-README.md` for details.

## Development Workflow

### Morning Setup

```bash
# Start VM
nix run .#run &

# Wait for boot
sleep 15

# Verify API
curl http://localhost:8000/health
```

### Working in the VM

```bash
# SSH in (auto-drops into tmux)
ssh user@127.0.0.1 -p 2222

# Inside VM:
cd /mnt/host-projects/my-project

# Use pre-configured Neovim with LSP
vim flake.nix  # Press <space>ff for file finder

# Run agent manually
aider --model claude-3-5-sonnet-20241022 --message "Add tests"

# Or via API from host
curl -X POST http://localhost:8000/agent/run \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"agent":"aider","prompt":"Add tests"}'
```

### Shutdown

```bash
# Graceful shutdown from inside VM
sudo shutdown -h now

# Or force quit from host (Ctrl+A then X in QEMU console)
```

## Integration Examples

### Python Integration

```python
from agent_vm_client import AgentVMClient, Agent

client = AgentVMClient(api_key="your-key")

# Run task
result = client.run_agent(
    Agent.AIDER,
    "Add comprehensive error handling",
    repo_path="/mnt/host-projects/backend"
)

if result.success:
    print("Changes applied successfully")
```

### Game Engine Integration (Unity)

```csharp
using UnityEngine;

public class AgentVMController : MonoBehaviour
{
    public void RunCodingTask(string prompt)
    {
        StartCoroutine(RunAgentCoroutine(prompt));
    }
    
    private IEnumerator RunAgentCoroutine(string prompt)
    {
        // See docs/EXAMPLES.md for complete implementation
    }
}
```

### CI/CD Integration (GitHub Actions)

```yaml
name: AI Code Review
on: pull_request

jobs:
  ai-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Review with AgentVM
        run: |
          curl -X POST "$AGENT_VM_URL/agent/run" \
            -H "X-API-Key: $AGENT_VM_API_KEY" \
            -d '{"agent":"aider","prompt":"Review changes"}'
```

See `docs/EXAMPLES.md` for complete examples.

## Security Considerations

### Network Isolation

- VM ports are localhost-only by default
- Firewall disabled (relies on QEMU user networking)
- No outbound restrictions (agents need API access)

### File System

- Host mounts are read-only to prevent accidental modifications
- VM disk is ephemeral (rebuild from flake for clean state)
- Recordings stored in user home directory

### API Security

- API key required for all operations
- Store keys in files, not in code (use `apiKeyFile`)
- Consider HTTPS reverse proxy for production

### Systemd Hardening

The API service runs with:
- `NoNewPrivileges=true`
- `PrivateTmp=true`
- `ProtectSystem=strict`
- `ProtectHome=read-only`

## Performance

### Resource Usage

```
Component           Memory Usage
────────────────────────────────
Base VM             ~500MB
Docker daemon       ~200MB
Python + FastAPI    ~100MB
Neovim + LSP        ~150MB
────────────────────────────────
Total (headless)    ~950MB

vs Electron UI:     ~1500MB+
```

### CPU Isolation

Core 0 is reserved for the host. Cores 1-7 are isolated via kernel `isolcpus` parameter for VM workloads. This ensures real-time host processes (e.g., DSP) are not interrupted.

## Troubleshooting

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :2222

# Kill it or choose different port in run script
```

### VM Won't Boot

```bash
# Rebuild from scratch
nix build .#agent-vm-qcow2 --rebuild

# Check QEMU output
nix run .#run 2>&1 | tee vm.log
```

### LSP Not Working

Inside VM:

```bash
# Check nixd is installed
which nixd

# Start Neovim with debug
nvim --cmd "set verbose=15"

# Check LSP status
:LspInfo
```

See `docs/TROUBLESHOOTING.md` for more solutions.

## Advanced Usage

### Using as a NixOS Module

Import into your existing NixOS configuration:

```nix
# configuration.nix
{
  imports = [
    (builtins.fetchGit {
      url = "https://github.com/ALH477/Oligarchy-Agent-VM";
      rev = "main";
    } + "/flake.nix#nixosModules.default")
  ];

  oligarchy.agent-vm = {
    enable = true;
    deploymentMode = "headless-ssh";
    # ... your config
  };
}
```

### Custom Agent Integration

Add your own agent to the API by modifying the `main.py` template in `flake.nix`:

```nix
cmd_map = {
  # ... existing agents
  "my-agent": ["my-agent-binary", "--flag", r.prompt],
}
```

### Secrets Management with sops-nix

```nix
# flake.nix
inputs.sops-nix.url = "github:Mic92/sops-nix";

# In module
{
  imports = [ inputs.sops-nix.nixosModules.sops ];
  
  sops.secrets.agent-api-key = {
    sopsFile = ./secrets.yaml;
    owner = "user";
  };
  
  oligarchy.agent-vm.apiKeyFile = config.sops.secrets.agent-api-key.path;
}
```

## Contributing

Contributions are welcome. Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For bugs, open an issue with:
- VM configuration
- Error logs
- Steps to reproduce

## License

MIT License. See LICENSE file for details.

## Acknowledgments

- **Anthropic** - Claude API and coding agents
- **NixOS** - Reproducible system configuration
- **aider-chat** - AI pair programming
- Built for real-time DSP development workflows

## Links

- GitHub: https://github.com/ALH477/Oligarchy-Agent-VM
- Documentation: See `docs/` directory
- Issues: https://github.com/ALH477/Oligarchy-Agent-VM/issues

## Project Status

**Active Development** - Production-ready for individual use. Enterprise features planned.

### Roadmap

- Cloud deployment configurations
- Multi-tenant support
- Web-based UI (in addition to GTK4)
- VS Code extension
- Enhanced monitoring and metrics
- Integration tests suite

## Support

For questions or issues:

1. Check documentation in `docs/`
2. Search existing issues
3. Open a new issue with details

Commercial support available for enterprise deployments.

---

Built with Nix. Powered by AI. Designed for developers who value reproducibility and performance.
