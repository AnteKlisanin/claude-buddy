# Claude Indicator

A macOS menu bar app that displays a visual "damage ring" effect around screen edges when Claude Code needs your attention—similar to low-health indicators in video games.

## Features

- **Screen-specific alerts**: Only blinks the screen where the terminal needing attention is located
- **Stacking alerts**: Multiple terminals = thicker ring (ring width increases per active alert)
- **Multi-monitor aware**: Each screen can have independent alert states
- **Customizable**: Change colors, opacity, thickness, blink speed, and more
- **Auto-dismiss**: Optionally auto-dismiss alerts after a configurable timeout

## Installation

### Build from source

```bash
./build-app.sh
cp -r "build/Claude Indicator.app" /Applications/
```

### Run

```bash
open "/Applications/Claude Indicator.app"
```

The app will appear in your menu bar as a circle icon.

## Claude Code Integration

Add the following hooks to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "type": "command",
      "command": "echo $PPID >> ~/.claude/claude-indicator-trigger"
    }],
    "Notification": [{
      "type": "command",
      "command": "echo $PPID >> ~/.claude/claude-indicator-trigger"
    }]
  }
}
```

This will trigger an alert whenever:
- Claude Code finishes responding (Stop hook)
- Claude Code needs your input (Notification hook)

## Permissions

The app requires **Accessibility permissions** to detect which screen your terminal window is on.

On first launch, you'll be prompted to grant access in:
**System Settings > Privacy & Security > Accessibility**

## Usage

### Menu Bar Icon
- **Left-click**: Dismiss all active alerts
- **Right-click**: Open menu (Settings, Quit)

### Keyboard Shortcut
- **Cmd+Shift+D**: Dismiss all alerts globally

### Settings

Access settings from the menu bar to configure:
- **Ring Color**: The color of the alert ring (default: red)
- **Ring Opacity**: How transparent the ring is (default: 60%)
- **Ring Thickness**: Base width of the ring in pixels (default: 80px)
- **Stacking Increment**: Additional width per stacked alert (default: +40px)
- **Blinking**: Enable/disable the pulsing animation
- **Blink Speed**: How fast the ring pulses (default: 1 second cycle)
- **Auto-dismiss**: Automatically dismiss alerts after a timeout

## How It Works

1. Claude Code hooks write the terminal's process ID (PID) to a trigger file
2. The app watches this file for changes
3. When triggered, it uses the Accessibility API to find which screen contains the terminal
4. A ring effect is drawn on that specific screen
5. Multiple alerts stack, making the ring thicker

## Supported Terminals

The app recognizes these terminal applications:
- Terminal.app
- iTerm2
- Alacritty
- WezTerm
- Hyper
- VS Code
- Cursor
- Warp
- IntelliJ IDEA
- MacVim
- Kitty

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools (for building)

## License

MIT
