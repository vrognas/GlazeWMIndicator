# GlazeWM Indicator

A native macOS menu bar indicator for [GlazeWM](https://github.com/glzr-io/glazewm) workspaces. Requires [GlazeWM](https://github.com/glzr-io/glazewm) to be installed and running.

<!-- TODO: Add screenshot -->

## Features

- Shows workspace indicators in the native macOS menu bar
- Click to switch workspaces
- Multi-monitor support with display separators
- Auto-reconnects when GlazeWM restarts
- No dependencies beyond macOS 13+

## Install

```sh
brew install --cask vrognas/tap/glazewm-indicator
```

Or download the latest release from [Releases](https://github.com/vrognas/glazewm-indicator/releases).

## Build from source

```sh
git clone https://github.com/vrognas/glazewm-indicator.git
cd glazewm-indicator
swift build -c release
```

## Requirements

- macOS 13.0+
- [GlazeWM](https://github.com/glzr-io/glazewm)

## Usage with GlazeWM

Add to your `~/.glzr/glazewm/config.yaml` to auto-launch with GlazeWM:

```yaml
general:
  startup_commands: ["shell-exec open -a 'GlazeWM Indicator'"]
  shutdown_commands: ["shell-exec pkill -x GlazeWMIndicator"]
```

## How it works

Connects to GlazeWM's WebSocket IPC server at `ws://localhost:6123`, subscribes to workspace events, and renders workspace indicators as native menu bar items. Workspaces without windows are hidden.

## Credits

- Inspired by [YabaiIndicator](https://github.com/xiamaz/YabaiIndicator), [SpaceId](https://github.com/dshnkao/SpaceId), and [WhichSpace](https://github.com/gechr/WhichSpace)
- Built for use with [GlazeWM](https://github.com/glzr-io/glazewm) by [glzr-io](https://github.com/glzr-io)

## License

MIT
