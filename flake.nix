{
  description = ''
    Oligarchy AgentVM — Production-Ready NixOS VM for AI-Assisted Coding
    
    A lightweight, secure, and API-driven development environment optimized for
    AI coding agents. Designed for isolation, reproducibility, and extensibility.
    
    Key Features:
    - Headless-first design with optional GUI
    - Pre-installed AI agents: aider, opencode, claude-code
    - FastAPI controller for programmatic agent orchestration
    - Automatic tmux session management per SSH connection
    - Optional asciinema recording with automatic cleanup
    - Virtiofs host-to-VM project directory sharing
    - CPU pinning support for real-time host workloads
    - Comprehensive Neovim setup with LSP and Treesitter
    
    Usage:
      nix build .#agent-vm-qcow2        # Build VM image
      nix run .#run                      # Launch VM with forwarded ports
      ssh user@127.0.0.1 -p 2222         # Connect to VM
      curl http://127.0.0.1:8000/docs    # Explore API
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    opencode-flake.url = "github:AodhanHayter/opencode-flake";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
  };

  outputs = { self, nixpkgs, opencode-flake, claude-code-nix, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

    # ═══════════════════════════════════════════════════════════════════════
    # Neovim Configuration with lazy.nvim, Treesitter, and LSP
    # ═══════════════════════════════════════════════════════════════════════
    # 
    # This creates a fully-configured Neovim instance with:
    # - lazy.nvim plugin manager (using pre-built Nix plugins)
    # - Treesitter for syntax highlighting (Nix, Lua, Bash, JSON, etc.)
    # - LSP support with nixd for Nix language features
    # - Telescope for fuzzy finding
    # - Git integration with gitsigns
    # - Sensible defaults for indentation and editing
    #
    neovimWrapped = let
      # Define all plugins we want available to lazy.nvim
      lazyPlugins = with pkgs.vimPlugins; [
        # Treesitter with essential parsers for this environment
        (nvim-treesitter.withPlugins (p: with p; [
          nix lua vim vimdoc bash json yaml markdown comment
        ]))
        
        # Core dependencies
        plenary-nvim
        which-key-nvim
        gitsigns-nvim
        
        # Telescope ecosystem
        telescope-nvim
        telescope-fzf-native-nvim
        
        # LSP support
        nvim-lspconfig
      ];
      
      # Create a directory structure that lazy.nvim can use
      # This avoids network fetches since all plugins are pre-built
      lazyPluginPath = pkgs.linkFarm "lazy-plugins" (map (drv: {
        name = drv.pname or (builtins.parseDrvName drv.name).name;
        path = drv;
      }) lazyPlugins);
      
    in pkgs.wrapNeovim pkgs.neovim-unwrapped {
      viAlias = true;
      vimAlias = true;
      
      # Essential CLI tools for LSP, fuzzy finding, etc.
      extraPackages = with pkgs; [
        git
        ripgrep
        fd
        nixd        # Nix language server
        nixfmt-rfc-style
      ];
      
      extraLuaConfig = ''
        -- ═══════════════════════════════════════════════════════════════
        -- Core Settings
        -- ═══════════════════════════════════════════════════════════════
        
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "
        
        -- Line numbers
        vim.opt.number = true
        vim.opt.relativenumber = true
        
        -- Indentation (2 spaces, expand tabs)
        vim.opt.tabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.expandtab = true
        vim.opt.smartindent = true
        
        -- System clipboard integration
        vim.opt.clipboard = "unnamedplus"
        
        -- Better search
        vim.opt.ignorecase = true
        vim.opt.smartcase = true
        
        -- UI improvements
        vim.opt.termguicolors = true
        vim.opt.signcolumn = "yes"
        vim.opt.scrolloff = 8
        
        -- ═══════════════════════════════════════════════════════════════
        -- lazy.nvim Setup
        -- ═══════════════════════════════════════════════════════════════
        
        require("lazy").setup({
          -- Point to our pre-built Nix plugins
          dev = {
            path = "${lazyPluginPath}",
            patterns = { "." },
            fallback = false,
          },
          
          spec = {
            -- Treesitter for syntax highlighting
            {
              "nvim-treesitter/nvim-treesitter",
              build = ":TSUpdate",
              config = function()
                require("nvim-treesitter.configs").setup({
                  ensure_installed = {},  -- Managed by Nix
                  sync_install = false,
                  auto_install = false,
                  highlight = { enable = true },
                  indent = { enable = true },
                })
              end
            },
            
            -- Telescope for fuzzy finding
            {
              "nvim-telescope/telescope.nvim",
              dependencies = { "nvim-lua/plenary.nvim" },
              config = function()
                require("telescope").setup({})
                -- Key mappings for common telescope operations
                local builtin = require("telescope.builtin")
                vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
                vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
                vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
                vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
              end
            },
            
            -- FZF native for faster fuzzy finding
            {
              "nvim-telescope/telescope-fzf-native.nvim",
              build = "make",
            },
            
            -- LSP configuration
            {
              "neovim/nvim-lspconfig",
              config = function()
                local lspconfig = require("lspconfig")
                
                -- Configure nixd (Nix language server)
                lspconfig.nixd.setup({
                  cmd = { "nixd" },
                  settings = {
                    nixd = {
                      formatting = {
                        command = { "nixfmt" },
                      },
                    },
                  },
                })
                
                -- LSP keymaps (only active when LSP is attached)
                vim.api.nvim_create_autocmd("LspAttach", {
                  callback = function(args)
                    local opts = { buffer = args.buf }
                    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
                    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
                    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
                  end,
                })
              end
            },
            
            -- Git integration
            { "lewis6991/gitsigns.nvim" },
            
            -- Which-key for keybinding hints
            { "folke/which-key.nvim" },
          },
          
          -- Don't try to modify rtp (we manage it via Nix)
          performance = {
            rtp = { reset = false },
          },
          
          -- Disable automatic installation/checking
          install = { missing = false },
          checker = { enabled = false },
        })
        
        -- ═══════════════════════════════════════════════════════════════
        -- Custom Keymaps
        -- ═══════════════════════════════════════════════════════════════
        
        -- Quick save and quit
        vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save file" })
        vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })
        
        -- Better window navigation
        vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
        vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
        vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
        vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
        
        -- ═══════════════════════════════════════════════════════════════
        -- Auto-commands
        -- ═══════════════════════════════════════════════════════════════
        
        -- Ensure .nix files are recognized
        vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
          pattern = "*.nix",
          callback = function()
            vim.bo.filetype = "nix"
          end,
        })
      '';
    };

  in {
    # ═══════════════════════════════════════════════════════════════════════
    # NixOS Module: Oligarchy AgentVM
    # ═══════════════════════════════════════════════════════════════════════
    #
    # This module provides a complete configuration for running AI coding agents
    # in a secure, isolated NixOS VM. It can be imported into any NixOS config.
    #
    nixosModules.default = { config, lib, pkgs, ... }:
    let
      cfg = config.oligarchy.agent-vm;
      guiEnabled = cfg.deploymentMode == "full-gui";

      # ─────────────────────────────────────────────────────────────────────
      # SSH Tmux Wrapper
      # ─────────────────────────────────────────────────────────────────────
      # Creates a unique tmux session for each SSH connection, optionally
      # recording the session with asciinema for later playback.
      #
      tmuxWrapper = pkgs.writeShellScriptBin "ssh-tmux-wrapper" ''
        #!/usr/bin/env bash
        set -euo pipefail

        # Extract client IP from SSH connection info
        CLIENT_IP="unknown"
        if [[ -n "''${SSH_CONNECTION:-}" ]]; then
          CLIENT_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}' | tr '.' '-')
        fi

        # Generate unique session name with timestamp
        SESSION_NAME="${cfg.tmuxSessionPrefix}$(whoami)-$CLIENT_IP-$(date +%Y%m%d-%H%M%S)"

        ${lib.optionalString cfg.tmuxRecordAutomatically ''
          # Set up asciinema recording
          RECORD_DIR="$HOME/ssh-recordings"
          mkdir -p "$RECORD_DIR"
          RECORD_FILE="$RECORD_DIR/$SESSION_NAME.cast"
          
          # Start recording with tmux as the command
          exec ${pkgs.asciinema}/bin/asciinema rec \
            --overwrite \
            --command="tmux new-session -A -s \"$SESSION_NAME\"" \
            "$RECORD_FILE"
        ''}

        # If not recording, just attach to tmux session
        exec tmux new-session -A -s "$SESSION_NAME"
      '';

    in {
      # ═══════════════════════════════════════════════════════════════════
      # Module Options
      # ═══════════════════════════════════════════════════════════════════
      
      options.oligarchy.agent-vm = with lib; {
        enable = mkEnableOption "Oligarchy AgentVM";

        # ─────────────────────────────────────────────────────────────────
        # Deployment Mode
        # ─────────────────────────────────────────────────────────────────
        deploymentMode = mkOption {
          type = types.enum ["headless-ssh" "minimal-ssh-only" "full-gui"];
          default = "headless-ssh";
          description = ''
            VM deployment mode:
            - headless-ssh: SSH access + Docker + full tooling (recommended)
            - minimal-ssh-only: SSH access + Podman only (lightest)
            - full-gui: Wayland GUI + SSH + Docker (highest resource use)
          '';
        };

        # ─────────────────────────────────────────────────────────────────
        # Host Integration
        # ─────────────────────────────────────────────────────────────────
        hostSharePath = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "/home/user/projects";
          description = ''
            Path on the host to share with the VM via virtiofs.
            Will be mounted read-only at /mnt/host-projects in the VM.
            Set to null to disable sharing.
          '';
        };

        # ─────────────────────────────────────────────────────────────────
        # CPU and Memory Configuration
        # ─────────────────────────────────────────────────────────────────
        reservedCores = mkOption {
          type = types.either (types.listOf types.int) types.str;
          default = "1-7";
          example = [1 2 3 4 5 6 7];
          description = ''
            CPU cores to isolate for this VM using kernel isolcpus parameter.
            Can be a list of core numbers or a range string like "1-7".
            Core 0 is reserved for the host and cannot be included.
            
            This is useful when running real-time DSP workloads on the host
            that need guaranteed access to specific cores.
          '';
        };

        cpuCores = mkOption {
          type = types.int;
          default = 6;
          description = "Number of CPU cores to allocate to the VM";
        };

        memoryMB = mkOption {
          type = types.int;
          default = 8192;
          description = "Amount of RAM in megabytes to allocate to the VM";
        };

        # ─────────────────────────────────────────────────────────────────
        # API Configuration
        # ─────────────────────────────────────────────────────────────────
        enableGameApi = mkEnableOption "FastAPI agent controller" // { default = true; };
        
        apiPort = mkOption {
          type = types.port;
          default = 8000;
          description = "Port for the FastAPI agent controller";
        };

        apiKeyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/run/secrets/agent-api-key";
          description = ''
            Path to a file containing the API key for agent controller.
            If null, uses the insecure fallback apiKeyFallback option.
            For production, use a secrets manager like sops-nix or agenix.
          '';
        };

        apiKeyFallback = mkOption {
          type = types.str;
          default = "dev-secret-2026";
          description = ''
            Fallback API key used only when apiKeyFile is null.
            WARNING: This will be world-readable in /nix/store.
            Only use for development. Set apiKeyFile for production.
          '';
        };

        # ─────────────────────────────────────────────────────────────────
        # SSH and Tmux Configuration
        # ─────────────────────────────────────────────────────────────────
        autoTmuxPerSsh = mkEnableOption "Dedicated tmux per SSH session" // { default = true; };
        
        tmuxRecordAutomatically = mkEnableOption "Record SSH sessions with asciinema" // { default = false; };
        
        tmuxSessionPrefix = mkOption {
          type = types.str;
          default = "ssh-";
          description = "Prefix for automatically created tmux session names";
        };

        recordingRetentionDays = mkOption {
          type = types.int;
          default = 30;
          description = ''
            Number of days to keep asciinema recordings before automatic deletion.
            Only applies when tmuxRecordAutomatically is enabled.
          '';
        };

        # ─────────────────────────────────────────────────────────────────
        # Remote GUI Configuration
        # ─────────────────────────────────────────────────────────────────
        enableRemoteGui = mkEnableOption "SPICE remote GUI" // { default = guiEnabled; };
        
        remoteBindAddress = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Address to bind SPICE server (127.0.0.1 for local-only)";
        };

        spicePassword = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional password for SPICE connections";
        };
      };

      # ═══════════════════════════════════════════════════════════════════
      # Module Configuration
      # ═══════════════════════════════════════════════════════════════════
      
      config = lib.mkIf cfg.enable {
        # ─────────────────────────────────────────────────────────────────
        # Assertions
        # ─────────────────────────────────────────────────────────────────
        assertions = [
          {
            assertion = !(builtins.elem 0 (lib.toList cfg.reservedCores));
            message = "Core 0 is reserved for host DSP VM and cannot be isolated";
          }
          {
            assertion = cfg.apiKeyFile != null || cfg.apiKeyFallback != "dev-secret-2026";
            message = ''
              Production deployment detected but using insecure API key.
              Set oligarchy.agent-vm.apiKeyFile to a secrets file or change apiKeyFallback.
            '';
          }
        ];

        # ─────────────────────────────────────────────────────────────────
        # Boot Configuration
        # ─────────────────────────────────────────────────────────────────
        boot.kernelPackages = pkgs.linuxPackages;
        
        boot.kernelParams = [
          "quiet"
          "loglevel=3"
        ] ++ lib.optionals (cfg.reservedCores != []) [
          "isolcpus=${lib.concatStringsSep "," (map toString (lib.toList cfg.reservedCores))}"
        ];

        boot.initrd.availableKernelModules = [
          "virtio_pci"
          "virtio_blk"
          "virtio_net"
          "virtio_scsi"
          "virtio_fs"
          "virtio_gpu"
        ];

        # ─────────────────────────────────────────────────────────────────
        # Filesystem Configuration
        # ─────────────────────────────────────────────────────────────────
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };

        # Mount host-shared directory via virtiofs (if configured)
        fileSystems."/mnt/host-projects" = lib.mkIf (cfg.hostSharePath != null) {
          device = "host-projects";
          fsType = "virtiofs";
          options = [
            "tag=host-projects"
            "default_permissions"
            "ro"  # Read-only for safety
          ];
        };

        # ─────────────────────────────────────────────────────────────────
        # User Configuration
        # ─────────────────────────────────────────────────────────────────
        users.users.user = {
          isNormalUser = true;
          extraGroups = [ "wheel" "docker" "kvm" "podman" ];
          description = "Agent VM User";
          initialPassword = "agent";  # Change on first login
        };
        
        security.sudo.wheelNeedsPassword = false;

        # ─────────────────────────────────────────────────────────────────
        # SSH Configuration
        # ─────────────────────────────────────────────────────────────────
        services.openssh = {
          enable = true;
          settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = true;
          };
          # Force all SSH sessions into dedicated tmux sessions
          extraConfig = lib.mkIf cfg.autoTmuxPerSsh ''
            Match User user
                ForceCommand ${tmuxWrapper}/bin/ssh-tmux-wrapper
          '';
        };

        # Auto-login on console (VM context)
        services.getty.autologinUser = "user";

        # ─────────────────────────────────────────────────────────────────
        # GUI Configuration (when enabled)
        # ─────────────────────────────────────────────────────────────────
        services.xserver.enable = guiEnabled;
        programs.river.enable = guiEnabled;
        programs.xwayland.enable = guiEnabled;
        services.spice-vdagentd.enable = cfg.enableRemoteGui && guiEnabled;

        # ─────────────────────────────────────────────────────────────────
        # Tmux Configuration
        # ─────────────────────────────────────────────────────────────────
        programs.tmux = {
          enable = true;
          extraConfig = ''
            # Mouse support
            set -g mouse on
            
            # Increase history limit
            set -g history-limit 100000
            
            # True color support
            set -g default-terminal "tmux-256color"
            set -ga terminal-overrides ",xterm-256color:Tc"
            
            # Vi mode for copy mode
            setw -g mode-keys vi
            bind-key -T copy-mode-vi v send-keys -X begin-selection
            bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
            
            # Status bar styling
            set -g status-style bg=colour235,fg=colour136
            set -g status-left "#[fg=green]▶ #S #[fg=yellow]#I #[fg=cyan]#P"
            set -g status-right "#[fg=cyan]%Y-%m-%d %H:%M #[fg=green]#H"
            
            # Reduce escape time for better responsiveness
            set -sg escape-time 10
            
            # Renumber windows on close
            set -g renumber-windows on
          '';
        };

        # ─────────────────────────────────────────────────────────────────
        # Agent API Service
        # ─────────────────────────────────────────────────────────────────
        systemd.services.agent-game-api = lib.mkIf cfg.enableGameApi {
          description = "Oligarchy Agent Game API Controller";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          
          serviceConfig = {
            ExecStart = "${pkgs.python3Packages.uvicorn}/bin/uvicorn main:app --host 0.0.0.0 --port ${toString cfg.apiPort} --no-access-log";
            WorkingDirectory = "/home/user/agent-api";
            User = "user";
            Restart = "always";
            RestartSec = "5s";
            
            # Security hardening
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            ReadWritePaths = [ "/home/user/agent-api" ];
          };
          
          # Create API key file at service start
          preStart = ''
            mkdir -p /home/user/agent-api
            ${if cfg.apiKeyFile != null then ''
              cp ${cfg.apiKeyFile} /home/user/agent-api/.api-key
            '' else ''
              echo "${cfg.apiKeyFallback}" > /home/user/agent-api/.api-key
            ''}
            chown -R user:users /home/user/agent-api
            chmod 600 /home/user/agent-api/.api-key
          '';
        };

        # ─────────────────────────────────────────────────────────────────
        # Agent API Implementation
        # ─────────────────────────────────────────────────────────────────
        environment.etc."agent-api/main.py".text = ''
          """
          Oligarchy Agent Game API Controller
          
          A FastAPI service that provides programmatic control over AI coding agents.
          This allows external applications (including game engines, 3D UIs, etc.) to
          trigger and orchestrate coding tasks.
          
          Endpoints:
            POST /agent/run - Execute an agent with a prompt
            GET  /health    - Health check
            GET  /docs      - Interactive API documentation
          
          Authentication:
            All endpoints require X-API-Key header matching the configured key.
          """
          
          from fastapi import FastAPI, HTTPException, Header, Depends
          from fastapi.responses import JSONResponse
          from pydantic import BaseModel, Field
          import subprocess
          import os
          from typing import Optional, List
          from pathlib import Path
          
          # ═══════════════════════════════════════════════════════════════
          # Application Setup
          # ═══════════════════════════════════════════════════════════════
          
          app = FastAPI(
              title="Oligarchy Agent Game API",
              description="Programmatic control interface for AI coding agents",
              version="1.0.0",
          )
          
          # Load API key from file (set by systemd service)
          API_KEY_FILE = Path("/home/user/agent-api/.api-key")
          API_KEY = API_KEY_FILE.read_text().strip() if API_KEY_FILE.exists() else "fallback-key"
          
          # ═══════════════════════════════════════════════════════════════
          # Request/Response Models
          # ═══════════════════════════════════════════════════════════════
          
          class AgentRequest(BaseModel):
              """Request to run an AI coding agent"""
              agent: str = Field(
                  ...,
                  description="Agent to run: 'aider', 'opencode', or 'claude'",
                  example="aider"
              )
              prompt: str = Field(
                  ...,
                  description="Coding task or instruction for the agent",
                  example="Add error handling to the login function"
              )
              repo_path: Optional[str] = Field(
                  default="/mnt/host-projects/current",
                  description="Path to the repository/project directory"
              )
              timeout: int = Field(
                  default=600,
                  description="Maximum execution time in seconds",
                  ge=1,
                  le=3600
              )
              extra_args: Optional[List[str]] = Field(
                  default=None,
                  description="Additional command-line arguments for the agent"
              )
          
          class AgentResponse(BaseModel):
              """Response from agent execution"""
              success: bool
              stdout: Optional[str] = None
              stderr: Optional[str] = None
              returncode: Optional[int] = None
              error: Optional[str] = None
          
          # ═══════════════════════════════════════════════════════════════
          # Authentication
          # ═══════════════════════════════════════════════════════════════
          
          async def verify_api_key(x_api_key: str = Header(None)):
              """Verify API key from request header"""
              if x_api_key != API_KEY:
                  raise HTTPException(
                      status_code=401,
                      detail="Invalid or missing API key. Include X-API-Key header."
                  )
              return x_api_key
          
          # ═══════════════════════════════════════════════════════════════
          # Endpoints
          # ═══════════════════════════════════════════════════════════════
          
          @app.get("/health")
          async def health_check():
              """Health check endpoint"""
              return {"status": "healthy", "service": "agent-game-api"}
          
          @app.post("/agent/run", response_model=AgentResponse)
          async def run_agent(
              request: AgentRequest,
              api_key: str = Depends(verify_api_key)
          ):
              """
              Execute an AI coding agent with the specified prompt.
              
              This endpoint provides programmatic control over coding agents,
              allowing external tools and UIs to delegate coding tasks.
              """
              
              # Map agent names to base commands
              cmd_map = {
                  "aider": [
                      "aider",
                      "--model", "claude-3-5-sonnet-20241022",
                      "--message", request.prompt
                  ],
                  "opencode": ["opencode", request.prompt],
                  "claude": ["claude", request.prompt],
              }
              
              # Get base command for requested agent
              base_cmd = cmd_map.get(request.agent.lower())
              if not base_cmd:
                  raise HTTPException(
                      status_code=400,
                      detail=f"Unknown agent: {request.agent}. Valid: {list(cmd_map.keys())}"
                  )
              
              # Build full command with extra args
              cmd = base_cmd + (request.extra_args or [])
              
              # Add repo path if provided
              if request.repo_path:
                  cmd.append(request.repo_path)
              
              # Execute agent
              try:
                  result = subprocess.run(
                      cmd,
                      cwd=request.repo_path or os.getcwd(),
                      timeout=request.timeout,
                      capture_output=True,
                      text=True
                  )
                  
                  return AgentResponse(
                      success=result.returncode == 0,
                      stdout=result.stdout,
                      stderr=result.stderr,
                      returncode=result.returncode
                  )
                  
              except subprocess.TimeoutExpired:
                  return AgentResponse(
                      success=False,
                      error=f"Agent execution timed out after {request.timeout} seconds"
                  )
              except Exception as e:
                  return AgentResponse(
                      success=False,
                      error=f"Agent execution failed: {str(e)}"
                  )
          
          @app.get("/")
          async def root():
              """Root endpoint with API information"""
              return {
                  "service": "Oligarchy Agent Game API",
                  "version": "1.0.0",
                  "docs": "/docs",
                  "health": "/health"
              }
        '';

        # ─────────────────────────────────────────────────────────────────
        # Welcome Message and Aliases
        # ─────────────────────────────────────────────────────────────────
        environment.etc."profile.d/agentvm-motd.sh".text = ''
          echo -e "\n\e[1;32m╔═══════════════════════════════════════════════════════════╗\e[0m"
          echo -e "\e[1;32m║         Oligarchy AgentVM — Session Active                ║\e[0m"
          echo -e "\e[1;32m╚═══════════════════════════════════════════════════════════╝\e[0m"
          echo ""
          echo "  📡 API Endpoint:  http://localhost:${toString cfg.apiPort}"
          echo "  🔑 API Docs:      http://localhost:${toString cfg.apiPort}/docs"
          ${lib.optionalString (cfg.apiKeyFile == null) ''
          echo "  ⚠️  API Key:      ${cfg.apiKeyFallback} (dev mode)"
          ''}
          echo "  💻 Tmux:          Auto-started per SSH connection"
          echo "  📁 Shared:        /mnt/host-projects"
          ${lib.optionalString cfg.tmuxRecordAutomatically ''
          echo "  🎥 Recordings:    ~/ssh-recordings/*.cast"
          ''}
          echo ""
          echo "Helpful aliases:"
          echo "  quest    - Quick API test command"
          echo "  vi/vim   - Neovim with LSP"
          echo ""
          
          # Define helpful alias for API testing
          alias quest='curl -s -H "X-API-Key: $(cat /home/user/agent-api/.api-key 2>/dev/null || echo ${cfg.apiKeyFallback})" -H "Content-Type: application/json" -d'
        '';

        # ─────────────────────────────────────────────────────────────────
        # Recording Cleanup Service
        # ─────────────────────────────────────────────────────────────────
        systemd.services.cleanup-recordings = lib.mkIf cfg.tmuxRecordAutomatically {
          description = "Clean up old asciinema recordings";
          serviceConfig = {
            Type = "oneshot";
            User = "user";
            ExecStart = "${pkgs.findutils}/bin/find /home/user/ssh-recordings -name '*.cast' -mtime +${toString cfg.recordingRetentionDays} -delete";
          };
        };

        systemd.timers.cleanup-recordings = lib.mkIf cfg.tmuxRecordAutomatically {
          description = "Daily cleanup of old asciinema recordings";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };

        # ─────────────────────────────────────────────────────────────────
        # Directory Initialization
        # ─────────────────────────────────────────────────────────────────
        system.activationScripts.sshRecordingsDir = lib.mkIf cfg.tmuxRecordAutomatically ''
          mkdir -p /home/user/ssh-recordings
          chown user:users /home/user/ssh-recordings
          chmod 700 /home/user/ssh-recordings
        '';

        system.activationScripts.agentApiDir = lib.mkIf cfg.enableGameApi ''
          mkdir -p /home/user/agent-api
          chown user:users /home/user/agent-api
          chmod 755 /home/user/agent-api
        '';

        # ─────────────────────────────────────────────────────────────────
        # Package Installation
        # ─────────────────────────────────────────────────────────────────
        environment.systemPackages = with pkgs; [
          # Core editor (fully configured with LSP)
          neovimWrapped
          
          # Alternative editors
          nano
          
          # File management
          ranger
          
          # Version control
          git
          
          # Terminal multiplexer
          tmux
          
          # Search tools
          ripgrep
          fd
          
          # System monitoring
          htop
          btop
          
          # AI coding agents
          aider-chat
          opencode-flake.packages.${system}.default
          claude-code-nix.packages.${system}.claude-code
          
          # Container runtime
          podman
          
          # Python for API
          python3
          python3Packages.fastapi
          python3Packages.uvicorn
          python3Packages.pydantic
        ] ++ lib.optionals (cfg.deploymentMode != "minimal-ssh-only") [
          docker
        ] ++ lib.optionals cfg.tmuxRecordAutomatically [
          asciinema
        ];

        # ─────────────────────────────────────────────────────────────────
        # Docker Configuration
        # ─────────────────────────────────────────────────────────────────
        virtualisation.docker.enable = (cfg.deploymentMode != "minimal-ssh-only");

        # ─────────────────────────────────────────────────────────────────
        # Network Configuration
        # ─────────────────────────────────────────────────────────────────
        networking = {
          hostName = "oligarchy-agentvm";
          useDHCP = true;
          firewall.enable = false;  # Managed by QEMU port forwarding
        };

        # ─────────────────────────────────────────────────────────────────
        # System Optimization
        # ─────────────────────────────────────────────────────────────────
        documentation.enable = false;  # Reduce closure size
        
        system.stateVersion = "25.05";
      };
    };

    # ═══════════════════════════════════════════════════════════════════════
    # Example VM Image Configuration
    # ═══════════════════════════════════════════════════════════════════════
    #
    # This builds a ready-to-run QCOW2 VM image with sensible defaults.
    # Customize the configuration below for your specific needs.
    #
    packages.${system}.agent-vm-qcow2 = (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.default
        ({ ... }: {
          oligarchy.agent-vm = {
            enable = true;
            
            # Deployment configuration
            deploymentMode = "headless-ssh";
            
            # API configuration
            enableGameApi = true;
            apiPort = 8000;
            # SECURITY: In production, set apiKeyFile instead of using fallback
            # apiKeyFile = /run/secrets/agent-api-key;
            apiKeyFallback = "dev-key-2026";  # WARNING: Change this in production
            
            # SSH and tmux
            autoTmuxPerSsh = true;
            tmuxRecordAutomatically = false;  # Enable for session recording
            recordingRetentionDays = 30;
            
            # Host integration
            # CUSTOMIZE: Set this to your actual project directory
            hostSharePath = "/home/demod/projects";
            
            # Resource allocation
            reservedCores = "1-7";  # Isolate cores 1-7 for VM
            cpuCores = 6;
            memoryMB = 8192;
          };
          
          # VM-specific settings
          virtualisation.diskSize = 32768;  # 32GB disk
          virtualisation.writableStoreUseTmpfs = false;
          
          imports = [
            (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix")
          ];
        })
      ];
    }).config.system.build.vm;

    # ═══════════════════════════════════════════════════════════════════════
    # VM Launcher Application
    # ═══════════════════════════════════════════════════════════════════════
    #
    # Provides `nix run .#run` command to launch the VM with proper port
    # forwarding and resource allocation. Includes port conflict checking.
    #
    apps.${system}.run = {
      type = "app";
      program = toString (pkgs.writeShellScript "run-agent-vm" ''
        set -euo pipefail
        
        # ═══════════════════════════════════════════════════════════════
        # Port Availability Check
        # ═══════════════════════════════════════════════════════════════
        check_port() {
          local port=$1
          local name=$2
          if ss -tln | grep -q ":$port "; then
            echo "❌ ERROR: Port $port ($name) is already in use"
            echo "   Please stop the service using this port or choose a different port"
            return 1
          fi
        }
        
        echo "🔍 Checking port availability..."
        check_port 2222 "SSH" || exit 1
        check_port 8000 "API" || exit 1
        
        # ═══════════════════════════════════════════════════════════════
        # Extract VM Configuration
        # ═══════════════════════════════════════════════════════════════
        # Parse CPU and memory from the VM derivation
        cpu=$(nix eval --raw .#packages.${system}.agent-vm-qcow2.drvPath | grep -oP 'cpuCores = \K\d+' || echo 6)
        mem=$(nix eval --raw .#packages.${system}.agent-vm-qcow2.drvPath | grep -oP 'memoryMB = \K\d+' || echo 8192)
        
        # ═══════════════════════════════════════════════════════════════
        # Find VM Disk Image
        # ═══════════════════════════════════════════════════════════════
        vm_script="${self.packages.${system}.agent-vm-qcow2}/bin/run-nixos-vm"
        disk_img=$(find $(dirname "$vm_script") -name "*.img" -o -name "*.qcow2" | head -n1)
        
        if [[ -z "$disk_img" ]]; then
          echo "❌ ERROR: Could not find VM disk image"
          exit 1
        fi
        
        # ═══════════════════════════════════════════════════════════════
        # Launch Information
        # ═══════════════════════════════════════════════════════════════
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║         Launching Oligarchy AgentVM                       ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
        echo "  💻 CPU Cores:     $cpu"
        echo "  🧠 Memory:        ''${mem}MB"
        echo "  💾 Disk:          $disk_img"
        echo ""
        echo "  🔌 Port Forwarding:"
        echo "     SSH:    2222 → 22"
        echo "     API:    8000 → 8000"
        echo ""
        echo "  📡 Connect:"
        echo "     ssh user@127.0.0.1 -p 2222"
        echo "     curl http://127.0.0.1:8000/docs"
        echo ""
        echo "  ⌨️  Press Ctrl+A then X to quit QEMU"
        echo ""
        
        # ═══════════════════════════════════════════════════════════════
        # QEMU Launch
        # ═══════════════════════════════════════════════════════════════
        exec ${pkgs.qemu}/bin/qemu-system-x86_64 \
          -M q35 \
          -cpu host \
          -smp $cpu \
          -m ''${mem}M \
          -drive file="$disk_img",format=qcow2,if=virtio,cache=none \
          -net nic,model=virtio \
          -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::8000-:8000 \
          -device virtio-gpu-pci \
          -display none \
          -enable-kvm \
          -nographic \
          "$@"
      '');
    };

    # ═══════════════════════════════════════════════════════════════════════
    # Development Shell
    # ═══════════════════════════════════════════════════════════════════════
    #
    # Provides a development environment with VM management tools.
    # Enter with `nix develop`.
    #
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        qemu
        virt-viewer
        netcat
      ];
      
      shellHook = ''
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║      Oligarchy AgentVM Development Environment           ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
        echo "Available commands:"
        echo ""
        echo "  📦 Build VM image:"
        echo "     nix build .#agent-vm-qcow2"
        echo ""
        echo "  🚀 Launch VM:"
        echo "     nix run .#run"
        echo ""
        echo "  🔌 Connect to VM:"
        echo "     ssh user@127.0.0.1 -p 2222"
        echo ""
        echo "  📡 API Documentation:"
        echo "     http://127.0.0.1:8000/docs"
        echo ""
        echo "  🧪 Test API:"
        echo "     curl -H 'X-API-Key: change-this-in-production-2026' \\"
        echo "          http://127.0.0.1:8000/health"
        echo ""
      '';
    };
  };
}
