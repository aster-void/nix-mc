# nix-mc-cli - Minecraft Server CLI Tool

A command-line interface for managing Minecraft servers via tmux sessions.

## Overview

This CLI tool provides a simple interface to interact with Minecraft servers running under the nix-mc NixOS module. Servers run within tmux sessions, allowing external command injection and log monitoring through Unix sockets.

## Commands

### `list` - List all servers
Display all available Minecraft servers with their current status.

```bash
nix-mc-cli list
# Output:
# survival    ● Running  (2 players)
# creative    ○ Stopped
# skyblock    ● Running  (0 players)
```

### `status <server>` - Show detailed server status
Display detailed information about a specific server.

```bash
nix-mc-cli status survival
# Output:
# Server: mc-survival
# Status: Running
# Players: 2 online
# Socket: /run/minecraft/survival.sock
# Session: Active
```

### `send <server> <command>` - Send command to server
Execute a command on the specified server non-interactively.

```bash
nix-mc-cli send survival "say Hello players!"
nix-mc-cli send survival "stop"
nix-mc-cli send survival "whitelist add player123"
```

### `tail <server> [lines]` - Show recent logs
Display recent log output from the server (default: 20 lines).

```bash
nix-mc-cli tail survival        # Show last 20 lines
nix-mc-cli tail survival 50     # Show last 50 lines
```

### `connect <server>` - Connect to interactive session
Attach to the server's tmux session for direct interaction.

```bash
nix-mc-cli connect survival
# Connects to mc-survival tmux session
# Press Ctrl+B then D to detach
```

## Technical Details

- **Socket Discovery**: Automatically detects servers via `/run/minecraft/*.sock`
- **Permission Check**: Validates access to tmux sockets
- **Error Handling**: Comprehensive validation and user-friendly error messages
- **Session Management**: Leverages tmux for reliable server communication

## Installation

This tool is distributed as a Nix package through the nix-mc flake:

```bash
nix run github:aster-void/nix-mc#nix-mc-cli -- list
```

## Requirements

- Access to `/run/minecraft/` directory
- Membership in `minecraft` group (for socket access)
- `tmux` available in PATH