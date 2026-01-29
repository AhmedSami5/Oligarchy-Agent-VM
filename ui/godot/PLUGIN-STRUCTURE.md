# AgentVM Godot Plugin - Directory Structure

This document shows the complete file structure for the AgentVM Godot plugin.

## Installation Structure

```
YourGodotProject/
├── project.godot
├── scenes/
├── scripts/
└── addons/
    └── agentvm/                        ← Plugin root
        ├── plugin.cfg                  ← Plugin metadata
        ├── plugin.gd                   ← Main plugin script
        ├── config.ini                  ← User configuration
        │
        ├── core/                       ← Core functionality
        │   └── agent_manager.gd        ← API communication manager
        │
        └── ui/                         ← User interface
            ├── agent_dock.gd           ← Main dock panel script
            ├── agent_dock.tscn         ← Main dock panel scene
            ├── bottom_panel.gd         ← Output panel script
            └── bottom_panel.tscn       ← Output panel scene
```

## File Descriptions

### Root Level (`addons/agentvm/`)

**plugin.cfg**
- Plugin metadata for Godot
- Defines name, version, description
- Specifies entry point script

**plugin.gd**
- Main plugin registration
- Handles enable/disable lifecycle
- Creates UI components
- Connects signals

**config.ini**
- User-editable configuration
- API URL and key
- Default agent selection
- UI preferences

### Core Directory (`addons/agentvm/core/`)

**agent_manager.gd**
- Singleton manager node
- HTTP request handling
- Task state management
- Signal emissions for events
- Quick action methods

### UI Directory (`addons/agentvm/ui/`)

**agent_dock.gd**
- Main control panel logic
- Prompt input handling
- Agent selection
- Quick action buttons
- Task list display

**agent_dock.tscn**
- UI layout for dock panel
- VBoxContainer hierarchy
- TextEdit for prompts
- ItemList for tasks
- Buttons and selectors

**bottom_panel.gd**
- Output panel logic
- Colored log display
- Auto-scroll functionality
- Clear button handler

**bottom_panel.tscn**
- UI layout for output panel
- TextEdit for logs
- Toolbar with controls

## Quick Installation

### Option 1: Automated Installer

```bash
./install-godot-plugin.sh /path/to/your/godot/project
```

The installer will:
1. Check if target is a Godot project
2. Create directory structure
3. Copy all files
4. Configure API settings interactively
5. Test connection to AgentVM

### Option 2: Manual Installation

```bash
# Navigate to your Godot project
cd /path/to/your/godot/project

# Create plugin directories
mkdir -p addons/agentvm/core
mkdir -p addons/agentvm/ui

# Copy files to correct locations
cp plugin.cfg addons/agentvm/
cp plugin.gd addons/agentvm/
cp config.ini addons/agentvm/
cp agent_manager.gd addons/agentvm/core/
cp agent_dock.gd addons/agentvm/ui/
cp agent_dock.tscn addons/agentvm/ui/
cp bottom_panel.gd addons/agentvm/ui/
cp bottom_panel.tscn addons/agentvm/ui/
```

Then:
1. Open project in Godot
2. Project → Project Settings → Plugins
3. Enable "Oligarchy AgentVM"

## File Relationships

```
plugin.gd (Entry Point)
    │
    ├─→ agent_manager.gd (Singleton)
    │       │
    │       ├─→ HTTP Requests to AgentVM API
    │       └─→ Emits signals (task_started, task_completed, etc.)
    │
    ├─→ agent_dock.tscn (UI)
    │       │
    │       └─→ agent_dock.gd (Logic)
    │               │
    │               └─→ Calls agent_manager methods
    │
    └─→ bottom_panel.tscn (UI)
            │
            └─→ bottom_panel.gd (Logic)
                    │
                    └─→ Listens to agent_manager signals
```

## Configuration Flow

```
1. User edits config.ini
2. plugin.gd reads config on enable
3. Passes values to agent_manager
4. agent_manager uses config for API calls
5. UI reads from agent_manager
```

## Signal Flow

```
User Action (UI)
    ↓
agent_dock.gd calls agent_manager.run_agent()
    ↓
agent_manager.gd emits task_started signal
    ↓
bottom_panel.gd receives signal
    ↓
Updates output display
    ↓
... agent runs ...
    ↓
agent_manager.gd emits task_completed/task_failed
    ↓
UI updates everywhere
```

## Path References

All internal path references in the code use:

```gdscript
# In plugin.gd
const DOCK_SCENE = preload("res://addons/agentvm/ui/agent_dock.tscn")
const BOTTOM_PANEL_SCENE = preload("res://addons/agentvm/ui/bottom_panel.tscn")
const AGENT_MANAGER = preload("res://addons/agentvm/core/agent_manager.gd")

# In any script accessing the manager
var agent_manager = get_node("/root/AgentVMManager")
```

## Customization Points

Want to modify the plugin? Here are key customization points:

**Add a new quick action:**
```
File: addons/agentvm/core/agent_manager.gd
Method: Add new quick_* method
File: addons/agentvm/ui/agent_dock.gd
Method: Add button in _setup_quick_actions()
```

**Change UI colors:**
```
File: addons/agentvm/ui/agent_dock.tscn
Edit: Theme overrides on UI nodes
```

**Add new agent:**
```
File: addons/agentvm/core/agent_manager.gd
Edit: Modify agent validation
File: addons/agentvm/ui/agent_dock.gd
Edit: Add option to agent_selector
```

**Modify API timeout:**
```
File: addons/agentvm/config.ini
Edit: timeout value under [agent] section
```

## Testing Checklist

After installation, verify:

- [ ] Plugin shows in Project Settings → Plugins
- [ ] Can enable plugin without errors
- [ ] AgentVM panel appears in editor
- [ ] Connection indicator is green
- [ ] Can type in prompt and select agent
- [ ] Run button is enabled
- [ ] Bottom panel shows "AgentVM Output" tab
- [ ] Test task runs successfully
- [ ] Output appears in bottom panel
- [ ] Task appears in task list with correct status

## Troubleshooting

**Plugin not showing:**
- Check files are in `addons/agentvm/` exactly
- Verify `plugin.cfg` has correct format
- Restart Godot editor

**Cannot connect:**
- Verify AgentVM is running: `curl http://localhost:8000/health`
- Check `config.ini` has correct URL
- Verify API key matches

**UI broken:**
- Verify all `.tscn` files are present
- Check console for script errors
- Try disabling and re-enabling plugin

**Tasks fail immediately:**
- Check bottom panel for error details
- Verify agent name is correct
- Check project path is accessible
- Verify AgentVM can access project directory

## Next Steps

1. Read [GODOT-README.md](GODOT-README.md) for usage guide
2. Try the quick actions on a test script
3. Explore the GDScript API for programmatic access
4. Build custom workflows for your project

## Support

For issues, questions, or contributions:
- Main AgentVM project repository
- Check AgentVM documentation
- Review example workflows in README
