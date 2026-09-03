# Workspaces (Per Monitor + App Icons)

An [Omarchy](https://omarchy.org/) bar widget combining **per-monitor workspace isolation** with **per-app window icons**.

This combines the per-monitor filtering from [omarchy-workspaces-per-monitor](https://github.com/ragnacron/omarchy-workspaces-per-monitor.git) with the app icon mapping and progressive scaling from [WorkspaceIcons](https://github.com/SaifOmar/WorkspaceIcons.git).

## Features

- **Per-monitor workspace filtering:** Each monitor's status bar only shows workspaces bound to that display.
- **Per-app window icons:** Shows icons for each running window next to its workspace number.
- **Per-monitor active highlighting:** Both monitors highlight their active workspace independently using `workspace.active`.
- **Live window sync:** Automatically updates icons when windows open, close, move workspaces, or change titles.
- **Configurable icon rules:** Comes with 130+ bundled icon rules in `icons.json` and supports live user overrides in `~/.config/omarchy/workspaces-icons.json`.
- **Vertical & horizontal support:** Automatically scales and fits icons on vertical bars, with an ellipsis (`…`) indicator for overflow.
- **Scroll to cycle:** Scroll the mouse wheel over the widget to cycle through the workspaces on that screen.

## Requirements

- Omarchy 4.x running Hyprland
- A Nerd Font installed and set as the bar font so app glyphs render properly
- Workspaces bound to monitors in `~/.config/hypr/monitors.lua`, e.g.:

```lua
hl.workspace_rule({ workspace = "1", monitor = "DP-2", persistent = true, default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-2", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-2", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-2", persistent = true })

hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-2", persistent = true, default = true })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-2", persistent = true })
```

## Installation

### Local installation

Copy or rsync the plugin folder to `~/.config/omarchy/plugins/`:

```bash
rsync -a --exclude .git \
  /home/simon/Work/omarchy-workspaces-per-monitor-icons/ \
  ~/.config/omarchy/plugins/simon.workspaces-per-monitor/
```

Then enable it in `~/.config/omarchy/shell.json` (or via `omarchy plugin enable simon.workspaces-per-monitor left`) and reload the shell:

```bash
omarchy restart shell
```

### From Git (once pushed to GitHub)

```bash
omarchy plugin add https://github.com/CoupOfConiston/omarchy-workspaces-per-monitor-icons.git --enable
```

## Configuration

In your `~/.config/omarchy/shell.json` layout entry:

```json
{
  "id": "simon.workspaces-per-monitor",
  "showNumberAlways": true,
  "deduplicateIcons": false,
  "iconSpacing": 4,
  "maxWorkspaceId": 10
}
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `showNumberAlways` | `bool` | `true` | When `true`, always shows the workspace number even when active. When `false`, displays the active dot glyph (`●`) when focused. |
| `deduplicateIcons` | `bool` | `false` | When `true`, collapses repeated identical icons on the same workspace. |
| `iconSpacing` | `int` | `4` | Space in pixels between the workspace number and icons / between icons. |
| `maxWorkspaceId` | `int` | `10` | Highest workspace ID to display. |
| `maxIconsPerWorkspace` | `int` | `0` | Max icons per workspace pill (`0` = unlimited). |

### Custom App Icons

To customize app icons without modifying the plugin files, create:
`~/.config/omarchy/workspaces-icons.json`

Example:
```json
[
  { "pattern": "steam", "icon": "󰓓" },
  { "pattern": "obsidian", "icon": "󱓧" }
]
```
These rules are matched before built-in rules and apply live without restarting the shell.

## License

MIT
