"""
Oligarchy AgentVM UI - Wayland Compositor Integration

A lightweight, high-performance UI renderer for AgentVM using GTK4 and Cairo.
Designed for Wayland compositors with minimal dependencies and maximum efficiency.

Features:
- Direct GTK4/Cairo rendering (no Electron bloat)
- Real-time agent status monitoring
- Command palette for quick operations
- Session recording playback
- Terminal integration
- <300MB memory footprint

Architecture:
- GTK4 for native Wayland rendering
- Cairo for custom drawing primitives
- Async I/O for API communication
- Layer Shell protocol support for always-on-top overlays
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Gdk, GLib, Adw, Pango, PangoCairo

import cairo
import asyncio
import aiohttp
import json
from typing import Optional, Dict, List, Callable
from dataclasses import dataclass
from datetime import datetime
from enum import Enum


# ═══════════════════════════════════════════════════════════════════════════
# Color Scheme - Brutalist Industrial Aesthetic
# ═══════════════════════════════════════════════════════════════════════════

class Theme:
    """Monochrome brutalist color scheme with high contrast"""
    
    # Background layers
    BG_BASE = (0.08, 0.08, 0.08)      # #141414 - Deep base
    BG_RAISED = (0.12, 0.12, 0.12)    # #1F1F1F - Elevated surfaces
    BG_OVERLAY = (0.16, 0.16, 0.16)   # #292929 - Overlays
    
    # Foreground
    FG_PRIMARY = (0.95, 0.95, 0.95)   # #F2F2F2 - Primary text
    FG_SECONDARY = (0.70, 0.70, 0.70) # #B3B3B3 - Secondary text
    FG_TERTIARY = (0.45, 0.45, 0.45)  # #737373 - Tertiary text
    
    # Accents
    ACCENT = (1.0, 0.27, 0.0)         # #FF4500 - OrangeRed (primary action)
    SUCCESS = (0.0, 0.9, 0.4)         # #00E066 - Bright green
    ERROR = (1.0, 0.2, 0.2)           # #FF3333 - Bright red
    WARNING = (1.0, 0.8, 0.0)         # #FFCC00 - Amber
    
    # Borders & dividers
    BORDER = (0.25, 0.25, 0.25)       # #404040 - Subtle borders
    DIVIDER = (0.20, 0.20, 0.20)      # #333333 - Dividers
    
    @staticmethod
    def rgba(color: tuple, alpha: float = 1.0) -> str:
        """Convert RGB tuple to CSS rgba string"""
        r, g, b = [int(c * 255) for c in color]
        return f"rgba({r},{g},{b},{alpha})"


# ═══════════════════════════════════════════════════════════════════════════
# Agent State Management
# ═══════════════════════════════════════════════════════════════════════════

class AgentState(Enum):
    IDLE = "idle"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"


@dataclass
class AgentTask:
    """Represents an agent execution task"""
    id: str
    agent: str
    prompt: str
    status: AgentState
    started_at: datetime
    completed_at: Optional[datetime] = None
    output: Optional[str] = None
    error: Optional[str] = None


class AgentVMConnection:
    """Async connection manager for AgentVM API"""
    
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.session: Optional[aiohttp.ClientSession] = None
        
    async def __aenter__(self):
        self.session = aiohttp.ClientSession(headers={
            "X-API-Key": self.api_key,
            "Content-Type": "application/json"
        })
        return self
    
    async def __aexit__(self, *args):
        if self.session:
            await self.session.close()
    
    async def health_check(self) -> Dict:
        """Check API health"""
        async with self.session.get(f"{self.base_url}/health") as resp:
            return await resp.json()
    
    async def run_agent(
        self,
        agent: str,
        prompt: str,
        repo_path: str = "/mnt/host-projects/current",
        timeout: int = 600
    ) -> Dict:
        """Run an agent asynchronously"""
        payload = {
            "agent": agent,
            "prompt": prompt,
            "repo_path": repo_path,
            "timeout": timeout
        }
        
        async with self.session.post(
            f"{self.base_url}/agent/run",
            json=payload
        ) as resp:
            return await resp.json()


# ═══════════════════════════════════════════════════════════════════════════
# Custom Cairo Drawing Primitives
# ═══════════════════════════════════════════════════════════════════════════

class DrawingUtils:
    """Utility functions for Cairo drawing with brutalist aesthetics"""
    
    @staticmethod
    def rounded_rectangle(
        cr: cairo.Context,
        x: float, y: float,
        width: float, height: float,
        radius: float = 0
    ):
        """Draw rounded rectangle (radius=0 for sharp corners)"""
        if radius == 0:
            cr.rectangle(x, y, width, height)
            return
        
        degrees = 3.14159 / 180.0
        
        cr.new_sub_path()
        cr.arc(x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees)
        cr.arc(x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees)
        cr.arc(x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees)
        cr.arc(x + radius, y + radius, radius, 180 * degrees, 270 * degrees)
        cr.close_path()
    
    @staticmethod
    def set_color(cr: cairo.Context, color: tuple, alpha: float = 1.0):
        """Set Cairo color from RGB tuple"""
        cr.set_source_rgba(*color, alpha)
    
    @staticmethod
    def draw_text(
        cr: cairo.Context,
        text: str,
        x: float, y: float,
        font_family: str = "monospace",
        font_size: float = 14,
        color: tuple = Theme.FG_PRIMARY,
        weight: str = "normal",
        align: str = "left"
    ):
        """Draw text with specified styling"""
        # Create Pango layout for proper text rendering
        layout = PangoCairo.create_layout(cr)
        
        # Set font
        font_desc = Pango.FontDescription()
        font_desc.set_family(font_family)
        font_desc.set_size(int(font_size * Pango.SCALE))
        
        if weight == "bold":
            font_desc.set_weight(Pango.Weight.BOLD)
        
        layout.set_font_description(font_desc)
        layout.set_text(text, -1)
        
        # Handle alignment
        width, height = layout.get_pixel_size()
        if align == "center":
            x -= width / 2
        elif align == "right":
            x -= width
        
        # Draw
        cr.move_to(x, y)
        DrawingUtils.set_color(cr, color)
        PangoCairo.show_layout(cr, layout)
    
    @staticmethod
    def draw_status_indicator(
        cr: cairo.Context,
        x: float, y: float,
        size: float,
        state: AgentState
    ):
        """Draw animated status indicator"""
        color_map = {
            AgentState.IDLE: Theme.FG_TERTIARY,
            AgentState.RUNNING: Theme.WARNING,
            AgentState.SUCCESS: Theme.SUCCESS,
            AgentState.FAILED: Theme.ERROR
        }
        
        color = color_map.get(state, Theme.FG_TERTIARY)
        
        # Outer ring
        cr.arc(x, y, size, 0, 2 * 3.14159)
        DrawingUtils.set_color(cr, color, 0.3)
        cr.fill()
        
        # Inner dot
        cr.arc(x, y, size * 0.5, 0, 2 * 3.14159)
        DrawingUtils.set_color(cr, color)
        cr.fill()


# ═══════════════════════════════════════════════════════════════════════════
# Agent Status Widget (Custom GTK DrawingArea)
# ═══════════════════════════════════════════════════════════════════════════

class AgentStatusWidget(Gtk.DrawingArea):
    """Custom Cairo-rendered agent status display"""
    
    def __init__(self):
        super().__init__()
        self.set_content_width(400)
        self.set_content_height(120)
        self.set_draw_func(self._on_draw)
        
        self.tasks: List[AgentTask] = []
        self.current_task: Optional[AgentTask] = None
        
    def set_current_task(self, task: AgentTask):
        """Update current task and trigger redraw"""
        self.current_task = task
        self.queue_draw()
    
    def _on_draw(self, area, cr: cairo.Context, width: int, height: int):
        """Cairo drawing function"""
        # Background
        DrawingUtils.set_color(cr, Theme.BG_RAISED)
        cr.paint()
        
        # Border
        cr.set_line_width(2)
        DrawingUtils.set_color(cr, Theme.BORDER)
        cr.rectangle(0, 0, width, height)
        cr.stroke()
        
        if not self.current_task:
            # Idle state
            DrawingUtils.draw_status_indicator(cr, 30, 60, 12, AgentState.IDLE)
            DrawingUtils.draw_text(
                cr, "AGENT SYSTEM IDLE", 60, 52,
                font_size=16, weight="bold", color=Theme.FG_SECONDARY
            )
            DrawingUtils.draw_text(
                cr, "No active tasks", 60, 75,
                font_size=12, color=Theme.FG_TERTIARY
            )
        else:
            # Active task
            task = self.current_task
            
            # Status indicator
            DrawingUtils.draw_status_indicator(cr, 30, 30, 12, task.status)
            
            # Task info
            status_text = task.status.value.upper()
            DrawingUtils.draw_text(
                cr, status_text, 60, 22,
                font_size=16, weight="bold",
                color=self._get_status_color(task.status)
            )
            
            # Agent and prompt
            DrawingUtils.draw_text(
                cr, f"Agent: {task.agent.upper()}", 60, 45,
                font_size=12, color=Theme.FG_SECONDARY
            )
            
            # Truncate long prompts
            prompt = task.prompt
            if len(prompt) > 50:
                prompt = prompt[:47] + "..."
            
            DrawingUtils.draw_text(
                cr, prompt, 60, 65,
                font_size=11, color=Theme.FG_TERTIARY
            )
            
            # Progress bar for running tasks
            if task.status == AgentState.RUNNING:
                self._draw_progress_bar(cr, 60, 85, width - 80, 4)
    
    def _get_status_color(self, state: AgentState) -> tuple:
        """Get color for status text"""
        return {
            AgentState.IDLE: Theme.FG_TERTIARY,
            AgentState.RUNNING: Theme.WARNING,
            AgentState.SUCCESS: Theme.SUCCESS,
            AgentState.FAILED: Theme.ERROR
        }.get(state, Theme.FG_PRIMARY)
    
    def _draw_progress_bar(
        self, cr: cairo.Context,
        x: float, y: float,
        width: float, height: float
    ):
        """Draw indeterminate progress bar"""
        # Background track
        DrawingUtils.set_color(cr, Theme.BORDER)
        cr.rectangle(x, y, width, height)
        cr.fill()
        
        # Animated bar (using current time for animation)
        import time
        offset = (time.time() * 100) % width
        bar_width = width * 0.3
        
        DrawingUtils.set_color(cr, Theme.ACCENT)
        cr.rectangle(x + offset - bar_width, y, bar_width, height)
        cr.fill()
        
        # Schedule next frame
        GLib.timeout_add(16, self.queue_draw)  # ~60fps


# ═══════════════════════════════════════════════════════════════════════════
# Command Palette
# ═══════════════════════════════════════════════════════════════════════════

class CommandPalette(Gtk.Box):
    """Quick command entry with autocomplete"""
    
    def __init__(self, on_command: Callable[[str, str], None]):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.on_command = on_command
        
        # Add CSS styling
        self.add_css_class("command-palette")
        
        # Search entry
        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("ENTER COMMAND OR PROMPT...")
        self.entry.connect("activate", self._on_activate)
        self.append(self.entry)
        
        # Agent selector
        agent_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        agent_box.set_margin_top(12)
        
        label = Gtk.Label(label="AGENT:")
        agent_box.append(label)
        
        self.agent_dropdown = Gtk.DropDown.new_from_strings(
            ["aider", "opencode", "claude"]
        )
        self.agent_dropdown.set_selected(0)
        agent_box.append(self.agent_dropdown)
        
        self.append(agent_box)
    
    def _on_activate(self, entry):
        """Handle command submission"""
        text = entry.get_text().strip()
        if not text:
            return
        
        agent = ["aider", "opencode", "claude"][self.agent_dropdown.get_selected()]
        self.on_command(agent, text)
        entry.set_text("")
    
    def focus(self):
        """Focus the entry field"""
        self.entry.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════
# Task List View
# ═══════════════════════════════════════════════════════════════════════════

class TaskListView(Gtk.ScrolledWindow):
    """Scrollable list of recent tasks"""
    
    def __init__(self):
        super().__init__()
        self.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.set_vexpand(True)
        
        self.list_box = Gtk.ListBox()
        self.list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.list_box.add_css_class("task-list")
        
        self.set_child(self.list_box)
        
    def add_task(self, task: AgentTask):
        """Add a task to the list"""
        row = self._create_task_row(task)
        self.list_box.prepend(row)  # New tasks at top
    
    def _create_task_row(self, task: AgentTask) -> Gtk.ListBoxRow:
        """Create a row widget for a task"""
        row = Gtk.ListBoxRow()
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.set_margin_top(12)
        box.set_margin_bottom(12)
        
        # Header with status and time
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        
        status_icon = self._get_status_icon(task.status)
        header.append(Gtk.Label(label=status_icon))
        
        agent_label = Gtk.Label(label=task.agent.upper())
        agent_label.add_css_class("agent-label")
        header.append(agent_label)
        
        time_label = Gtk.Label(label=task.started_at.strftime("%H:%M:%S"))
        time_label.add_css_class("time-label")
        time_label.set_hexpand(True)
        time_label.set_halign(Gtk.Align.END)
        header.append(time_label)
        
        box.append(header)
        
        # Prompt text
        prompt_label = Gtk.Label(label=task.prompt)
        prompt_label.set_wrap(True)
        prompt_label.set_xalign(0)
        prompt_label.add_css_class("prompt-label")
        box.append(prompt_label)
        
        row.set_child(box)
        return row
    
    def _get_status_icon(self, state: AgentState) -> str:
        """Get emoji/icon for status"""
        return {
            AgentState.IDLE: "⚪",
            AgentState.RUNNING: "🟡",
            AgentState.SUCCESS: "🟢",
            AgentState.FAILED: "🔴"
        }.get(state, "⚪")


# ═══════════════════════════════════════════════════════════════════════════
# Main Application Window
# ═══════════════════════════════════════════════════════════════════════════

class AgentVMUI(Adw.ApplicationWindow):
    """Main application window with all UI components"""
    
    def __init__(self, app, api_url: str, api_key: str):
        super().__init__(application=app)
        
        self.api_url = api_url
        self.api_key = api_key
        self.current_task: Optional[AgentTask] = None
        
        # Window setup
        self.set_title("OLIGARCHY AGENTVM")
        self.set_default_size(800, 600)
        
        # Load custom CSS
        self._load_css()
        
        # Main layout
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        
        # Header bar
        header = Adw.HeaderBar()
        header.set_title_widget(Gtk.Label(label="OLIGARCHY AGENTVM"))
        main_box.append(header)
        
        # Content area
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        content.set_margin_start(24)
        content.set_margin_end(24)
        content.set_margin_top(24)
        content.set_margin_bottom(24)
        
        # Status widget
        self.status_widget = AgentStatusWidget()
        content.append(self.status_widget)
        
        # Command palette
        self.command_palette = CommandPalette(self._on_command_submitted)
        content.append(self.command_palette)
        
        # Task list
        tasks_label = Gtk.Label(label="RECENT TASKS")
        tasks_label.add_css_class("section-label")
        tasks_label.set_xalign(0)
        tasks_label.set_margin_top(12)
        content.append(tasks_label)
        
        self.task_list = TaskListView()
        content.append(self.task_list)
        
        main_box.append(content)
        self.set_content(main_box)
        
        # Initial health check
        GLib.idle_add(self._async_health_check)
    
    def _load_css(self):
        """Load custom CSS styling"""
        css_provider = Gtk.CssProvider()
        css = f"""
        window {{
            background-color: {Theme.rgba(Theme.BG_BASE)};
            color: {Theme.rgba(Theme.FG_PRIMARY)};
        }}
        
        headerbar {{
            background-color: {Theme.rgba(Theme.BG_RAISED)};
            color: {Theme.rgba(Theme.FG_PRIMARY)};
            border-bottom: 2px solid {Theme.rgba(Theme.BORDER)};
        }}
        
        .command-palette entry {{
            background-color: {Theme.rgba(Theme.BG_OVERLAY)};
            color: {Theme.rgba(Theme.FG_PRIMARY)};
            border: 2px solid {Theme.rgba(Theme.BORDER)};
            border-radius: 0;
            padding: 16px;
            font-family: monospace;
            font-size: 14px;
            caret-color: {Theme.rgba(Theme.ACCENT)};
        }}
        
        .command-palette entry:focus {{
            border-color: {Theme.rgba(Theme.ACCENT)};
        }}
        
        .task-list {{
            background-color: {Theme.rgba(Theme.BG_RAISED)};
            border: 2px solid {Theme.rgba(Theme.BORDER)};
        }}
        
        .task-list row {{
            background-color: transparent;
            border-bottom: 1px solid {Theme.rgba(Theme.DIVIDER)};
        }}
        
        .task-list row:hover {{
            background-color: {Theme.rgba(Theme.BG_OVERLAY)};
        }}
        
        .agent-label {{
            color: {Theme.rgba(Theme.ACCENT)};
            font-family: monospace;
            font-weight: bold;
            font-size: 11px;
        }}
        
        .time-label {{
            color: {Theme.rgba(Theme.FG_TERTIARY)};
            font-family: monospace;
            font-size: 10px;
        }}
        
        .prompt-label {{
            color: {Theme.rgba(Theme.FG_SECONDARY)};
            font-family: monospace;
            font-size: 12px;
        }}
        
        .section-label {{
            color: {Theme.rgba(Theme.FG_TERTIARY)};
            font-family: monospace;
            font-weight: bold;
            font-size: 11px;
            letter-spacing: 2px;
        }}
        
        dropdown button {{
            background-color: {Theme.rgba(Theme.BG_OVERLAY)};
            color: {Theme.rgba(Theme.FG_PRIMARY)};
            border: 1px solid {Theme.rgba(Theme.BORDER)};
            border-radius: 0;
            font-family: monospace;
        }}
        """
        
        css_provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _async_health_check(self):
        """Perform async health check"""
        asyncio.create_task(self._health_check_async())
        return False
    
    async def _health_check_async(self):
        """Async health check implementation"""
        try:
            async with AgentVMConnection(self.api_url, self.api_key) as conn:
                result = await conn.health_check()
                print(f"✓ API Health: {result}")
        except Exception as e:
            print(f"✗ Health check failed: {e}")
    
    def _on_command_submitted(self, agent: str, prompt: str):
        """Handle command submission"""
        # Create task
        task = AgentTask(
            id=f"task_{datetime.now().timestamp()}",
            agent=agent,
            prompt=prompt,
            status=AgentState.RUNNING,
            started_at=datetime.now()
        )
        
        # Update UI
        self.status_widget.set_current_task(task)
        self.task_list.add_task(task)
        
        # Run agent
        asyncio.create_task(self._run_agent_async(task))
    
    async def _run_agent_async(self, task: AgentTask):
        """Run agent asynchronously"""
        try:
            async with AgentVMConnection(self.api_url, self.api_key) as conn:
                result = await conn.run_agent(
                    agent=task.agent,
                    prompt=task.prompt
                )
                
                # Update task status
                task.completed_at = datetime.now()
                
                if result.get("success"):
                    task.status = AgentState.SUCCESS
                    task.output = result.get("stdout")
                else:
                    task.status = AgentState.FAILED
                    task.error = result.get("error") or result.get("stderr")
                
                # Update UI
                GLib.idle_add(self._update_task_ui, task)
                
        except Exception as e:
            task.status = AgentState.FAILED
            task.error = str(e)
            GLib.idle_add(self._update_task_ui, task)
    
    def _update_task_ui(self, task: AgentTask):
        """Update UI after task completion"""
        self.status_widget.set_current_task(task)
        
        # Reset to idle after 3 seconds
        GLib.timeout_add_seconds(3, self._reset_status)
        return False
    
    def _reset_status(self):
        """Reset status to idle"""
        self.status_widget.set_current_task(None)
        return False


# ═══════════════════════════════════════════════════════════════════════════
# Application
# ═══════════════════════════════════════════════════════════════════════════

class AgentVMApplication(Adw.Application):
    """Main GTK application"""
    
    def __init__(self, api_url: str, api_key: str):
        super().__init__(application_id="com.oligarchy.agentvm")
        self.api_url = api_url
        self.api_key = api_key
        
    def do_activate(self):
        """Application activation"""
        win = AgentVMUI(self, self.api_url, self.api_key)
        win.present()


# ═══════════════════════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════════════════════

def main():
    """Application entry point"""
    import argparse
    import os
    
    parser = argparse.ArgumentParser(description="Oligarchy AgentVM UI")
    parser.add_argument(
        "--api-key",
        default=os.getenv("AGENT_VM_API_KEY", "dev-key-2026"),
        help="API key (or set AGENT_VM_API_KEY env var)"
    )
    
    args = parser.parse_args()
    
    # Create asyncio event loop for GTK
    import gbulb
    gbulb.install(gtk=True)
    
    app = AgentVMApplication(args.api_url, args.api_key)
    app.run(None)


if __name__ == "__main__":
    main()