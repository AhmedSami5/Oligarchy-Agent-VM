# Troubleshooting Guide

Common issues and solutions for Oligarchy AgentVM.

## Table of Contents

- [VM Startup Issues](#vm-startup-issues)
- [Port Conflicts](#port-conflicts)
- [API Connection Problems](#api-connection-problems)
- [Agent Execution Failures](#agent-execution-failures)
- [SSH Connection Issues](#ssh-connection-issues)
- [Neovim/LSP Problems](#neovim-lsp-problems)
- [Performance Issues](#performance-issues)
- [Recording Problems](#recording-problems)
- [UI-Specific Issues](#ui-specific-issues)

---

## VM Startup Issues

### VM Fails to Boot

**Symptoms:**
- QEMU exits immediately
- Error messages about missing files
- Kernel panic

**Solutions:**

1. **Rebuild the VM image:**
   ```bash
   nix build .#agent-vm-qcow2 --rebuild
   ```

2. **Check disk space:**
   ```bash
   df -h
   # Ensure at least 10GB free
   ```

3. **Verify QEMU/KVM support:**
   ```bash
   # Check virtualization is enabled
   egrep -c '(vmx|svm)' /proc/cpuinfo  # Should be > 0
   
   # Check KVM module
   lsmod | grep kvm
   ```

4. **Check QEMU output:**
   ```bash
   nix run .#run 2>&1 | tee vm.log
   # Review vm.log for specific errors
   ```

### "Cannot allocate memory" Error

**Cause:** Insufficient RAM for requested VM size

**Solution:**
```nix
# In flake.nix, reduce memory allocation
oligarchy.agent-vm = {
  memoryMB = 4096;  # Reduce from 8192
};
```

Or increase host swap space.

### Kernel Boot Hangs

**Symptoms:**
- VM boots but hangs at "Loading kernel"
- No getty login prompt

**Solutions:**

1. **Check CPU isolation string:**
   ```nix
   # Ensure format is correct
   reservedCores = "1-7";  # Not "1,2,3,4,5,6,7"
   ```

2. **Try without CPU isolation:**
   ```nix
   reservedCores = "";  # Disable temporarily
   ```

3. **Increase boot timeout:**
   Edit run script, add longer sleep after QEMU launch.

---

## Port Conflicts

### SSH Port 2222 Already in Use

**Symptoms:**
```
bind: Address already in use
```

**Solutions:**

1. **Find process using port:**
   ```bash
   sudo lsof -i :2222
   # or
   sudo netstat -tulpn | grep 2222
   ```

2. **Kill the process:**
   ```bash
   sudo kill -9 <PID>
   ```

3. **Use different port:**
   Edit run script:
   ```bash
   -netdev user,id=net0,hostfwd=tcp::2223-:22  # Change 2222 to 2223
   ```

### API Port 8000 Already in Use

**Symptoms:**
- Cannot connect to API
- Port conflict message

**Solutions:**

1. **Check what's using the port:**
   ```bash
   sudo lsof -i :8000
   ```

2. **Change API port:**
   ```nix
   oligarchy.agent-vm = {
     apiPort = 8001;  # Use different port
   };
   ```

3. **Update API clients:**
   ```bash
   export AGENT_VM_URL="http://localhost:8001"
   ```

---

## API Connection Problems

### "Connection Refused" Error

**Symptoms:**
```bash
curl http://localhost:8000/health
# curl: (7) Failed to connect to localhost port 8000: Connection refused
```

**Solutions:**

1. **Wait for boot to complete:**
   ```bash
   # Give VM more time to start
   sleep 30
   curl http://localhost:8000/health
   ```

2. **Check if API service is running:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   systemctl status agent-api.service
   ```

3. **Check API logs:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   journalctl -u agent-api.service -f
   ```

4. **Verify port forwarding:**
   Inside VM:
   ```bash
   curl http://localhost:8000/health  # Should work inside VM
   ```
   If works inside but not outside, check QEMU hostfwd settings.

### "Unauthorized" / 401 Error

**Symptoms:**
```json
{"detail":"Invalid API key"}
```

**Solutions:**

1. **Check API key:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   cat /home/user/agent-api/.api-key
   ```

2. **Use correct key in requests:**
   ```bash
   export API_KEY="$(ssh user@127.0.0.1 -p 2222 cat /home/user/agent-api/.api-key)"
   curl -H "X-API-Key: $API_KEY" http://localhost:8000/health
   ```

3. **Reset API key:**
   Rebuild VM or manually edit `/home/user/agent-api/.api-key` inside VM.

---

## Agent Execution Failures

### Agent Returns "Command not found"

**Symptoms:**
```json
{"success": false, "error": "Command not found"}
```

**Solutions:**

1. **Verify agent is installed:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   which aider
   which opencode
   which claude
   ```

2. **Check deployment mode:**
   ```nix
   # Ensure you're not using minimal-ssh-only if you need full agents
   deploymentMode = "headless-ssh";  # Not minimal-ssh-only
   ```

3. **Rebuild VM:**
   ```bash
   nix build .#agent-vm-qcow2 --rebuild
   ```

### Agent Times Out

**Symptoms:**
```json
{"success": false, "error": "Timeout after 600 seconds"}
```

**Solutions:**

1. **Increase timeout:**
   ```bash
   curl -X POST http://localhost:8000/agent/run \
     -H "X-API-Key: $API_KEY" \
     -d '{"agent":"aider","prompt":"...","timeout":1200}'
   ```

2. **Simplify prompt:**
   Break large tasks into smaller chunks.

3. **Check agent is not stuck:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   ps aux | grep aider
   # If stuck, kill and retry
   ```

### "Repository not found" Error

**Symptoms:**
```
No git repository found
```

**Solutions:**

1. **Verify repo_path:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   ls /mnt/host-projects/your-repo
   git -C /mnt/host-projects/your-repo status
   ```

2. **Check host mount:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   mount | grep virtiofs
   ```

3. **Initialize git in repo:**
   ```bash
   cd /mnt/host-projects/your-repo
   git init
   ```

---

## SSH Connection Issues

### "Connection refused" to SSH

**Symptoms:**
```bash
ssh user@127.0.0.1 -p 2222
# ssh: connect to host 127.0.0.1 port 2222: Connection refused
```

**Solutions:**

1. **Wait for VM to boot:**
   ```bash
   # Try again after 30 seconds
   sleep 30
   ssh user@127.0.0.1 -p 2222
   ```

2. **Check SSH service:**
   Via QEMU console:
   ```bash
   systemctl status sshd
   ```

3. **Verify port forwarding:**
   ```bash
   ps aux | grep qemu  # Check hostfwd parameter
   ```

### "Permission denied (publickey)"

**Symptoms:**
- Cannot login with password
- Key authentication fails

**Solutions:**

1. **Use password authentication:**
   ```bash
   ssh -o PreferredAuthentications=password user@127.0.0.1 -p 2222
   # Default password: "agent"
   ```

2. **Set up SSH keys:**
   ```bash
   # Generate key if needed
   ssh-keygen -t ed25519
   
   # Copy to VM
   ssh-copy-id -p 2222 user@127.0.0.1
   ```

3. **Check SSH config:**
   Inside VM at `/etc/ssh/sshd_config`:
   ```
   PasswordAuthentication yes
   ```

### Tmux Not Starting Automatically

**Symptoms:**
- SSH connects but no tmux session
- Regular shell prompt instead

**Solutions:**

1. **Check tmux configuration:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   cat ~/.profile  # Should have tmux auto-start logic
   ```

2. **Manually start tmux:**
   ```bash
   tmux new-session -s manual
   ```

3. **Verify autoTmuxPerSsh setting:**
   ```nix
   oligarchy.agent-vm = {
     autoTmuxPerSsh = true;  # Should be enabled
   };
   ```

---

## Neovim/LSP Problems

### LSP Not Attaching

**Symptoms:**
- No autocomplete
- `:LspInfo` shows "No LSP clients"

**Solutions:**

1. **Check nixd is installed:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   which nixd
   ```

2. **Verify LSP configuration:**
   ```bash
   nvim test.nix
   :LspInfo  # Should show nixd attached to .nix files
   ```

3. **Check LSP logs:**
   ```bash
   :lua vim.cmd('edit ' .. vim.lsp.get_log_path())
   ```

4. **Restart LSP:**
   ```bash
   :LspRestart
   ```

### Treesitter Highlighting Not Working

**Symptoms:**
- No syntax highlighting
- Monochrome text

**Solutions:**

1. **Install treesitter parsers:**
   ```bash
   :TSInstall nix lua python
   ```

2. **Check treesitter status:**
   ```bash
   :checkhealth nvim-treesitter
   ```

3. **Verify configuration:**
   ```bash
   cat ~/.config/nvim/init.lua | grep treesitter
   ```

### Telescope Not Finding Files

**Symptoms:**
- `<space>ff` does nothing
- No file picker appears

**Solutions:**

1. **Check ripgrep is installed:**
   ```bash
   which rg
   ```

2. **Test telescope manually:**
   ```bash
   :Telescope find_files
   ```

3. **Verify key mapping:**
   ```bash
   :map <space>ff
   ```

---

## Performance Issues

### High CPU Usage

**Symptoms:**
- Host system slows down
- VM unresponsive

**Solutions:**

1. **Check CPU allocation:**
   ```nix
   cpuCores = 4;  # Reduce if too high
   ```

2. **Verify CPU isolation:**
   ```bash
   # On host
   cat /proc/cmdline | grep isolcpus
   ```

3. **Check for runaway processes:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   top  # Look for high CPU processes
   ```

### High Memory Usage

**Symptoms:**
- Out of memory errors
- System swap usage high

**Solutions:**

1. **Reduce VM memory:**
   ```nix
   memoryMB = 4096;  # Reduce from 8192
   ```

2. **Check memory usage inside VM:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   free -h
   ```

3. **Disable Docker if not needed:**
   ```nix
   deploymentMode = "minimal-ssh-only";
   ```

### Slow Disk I/O

**Symptoms:**
- Git operations slow
- File operations laggy

**Solutions:**

1. **Use native path in repo_path:**
   ```bash
   # Inside VM, use /mnt/host-projects
   # Not NFS or remote mounts
   ```

2. **Check virtiofs mount:**
   ```bash
   mount | grep virtiofs
   # Should show cache=auto
   ```

---

## Recording Problems

### Recordings Not Being Created

**Symptoms:**
- `/home/user/ssh-recordings/` is empty
- No .cast files

**Solutions:**

1. **Check recording is enabled:**
   ```nix
   tmuxRecordAutomatically = true;
   ```

2. **Verify asciinema is installed:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   which asciinema
   ```

3. **Check tmux configuration:**
   ```bash
   cat ~/.tmux.conf | grep asciinema
   ```

### Old Recordings Not Being Cleaned Up

**Symptoms:**
- Disk fills up with .cast files
- Cleanup timer not running

**Solutions:**

1. **Check cleanup service:**
   ```bash
   ssh user@127.0.0.1 -p 2222
   systemctl status cleanup-recordings.service
   systemctl status cleanup-recordings.timer
   ```

2. **Manually clean old recordings:**
   ```bash
   find ~/ssh-recordings -name "*.cast" -mtime +30 -delete
   ```

3. **Adjust retention:**
   ```nix
   recordingRetentionDays = 7;  # Keep only 1 week
   ```

---

## UI-Specific Issues

### GTK4 UI Won't Start

**Symptoms:**
```
gi.repository not found
```

**Solutions:**

1. **Install dependencies:**
   ```bash
   nix-shell -p python3Packages.pygobject3 gtk4
   ```

2. **Use provided shell.nix:**
   ```bash
   cd ui/wayland
   nix-shell
   ./test-ui.sh
   ```

3. **Check GObject introspection:**
   ```bash
   python3 -c "import gi; gi.require_version('Gtk', '4.0')"
   ```

### Godot Plugin Not Appearing

**Symptoms:**
- Plugin not in Project Settings
- No AgentVM panel

**Solutions:**

1. **Verify file structure:**
   ```bash
   ls YourProject/addons/agentvm/
   # Should show plugin.cfg, plugin.gd, etc.
   ```

2. **Check plugin.cfg format:**
   ```bash
   cat addons/agentvm/plugin.cfg
   # Verify no syntax errors
   ```

3. **Restart Godot:**
   Close and reopen the project.

4. **Check Godot console for errors:**
   Look for red error messages on startup.

### Plugin Cannot Connect to API

**Symptoms:**
- Connection indicator red
- "Not connected to API" message

**Solutions:**

1. **Verify API is running:**
   ```bash
   curl http://localhost:8000/health
   ```

2. **Check config.ini:**
   ```bash
   cat addons/agentvm/config.ini
   # Verify URL and key are correct
   ```

3. **Test connection manually:**
   ```bash
   curl -H "X-API-Key: YOUR_KEY" http://localhost:8000/health
   ```

---

## Getting Help

If none of these solutions work:

1. **Collect diagnostic information:**
   ```bash
   # VM logs
   nix run .#run 2>&1 | tee vm.log
   
   # API logs
   ssh user@127.0.0.1 -p 2222 journalctl -u agent-api.service > api.log
   
   # System info
   nix-shell -p nix-info --run nix-info > system.log
   ```

2. **Open an issue:**
   - Go to GitHub Issues
   - Include logs and configuration
   - Describe expected vs actual behavior

3. **Check existing issues:**
   - Search closed issues for solutions
   - Review discussions

---

## Preventive Measures

### Regular Maintenance

```bash
# Weekly: Rebuild VM to ensure latest updates
nix build .#agent-vm-qcow2 --rebuild

# Monthly: Clean Nix store
nix-collect-garbage -d

# Before major changes: Backup configuration
cp flake.nix flake.nix.backup
```

### Best Practices

- Always use `apiKeyFile` in production
- Keep `flake.lock` in version control
- Test changes in minimal-ssh-only mode first
- Monitor VM resource usage
- Document custom modifications

---

For additional help, consult:
- Main README.md
- EXAMPLES.md
- GitHub Issues
