# CLAUDE.md

This file provides guidance for Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Nix flake that provides NixOS modules for running Minecraft servers (Forge, NeoForge, and Bedrock). The module creates systemd services with proper security hardening and file management.

## Architecture

**Core Components:**
- `flake.nix`: Entry point that exposes the NixOS module
- `nixosModules/nix-mc.nix`: Main NixOS module implementing Minecraft server management

**Key Design Patterns:**
- **Separation of Concerns**: `upstreamDir` (read-only server files) vs `dataDir` (persistent world data)
- **Security Hardening**: Systemd services run with `NoNewPrivileges`, `ProtectSystem=strict`, and restricted capabilities
- **File Sync Strategy**: Configurable choice between symlinks vs file copying for different content types
- **Multi-Server Support**: Single module manages multiple server instances with individual configurations

**Service Architecture:**
- Each server has its own `minecraft-${name}` systemd service
- Servers run within `tmux` sessions for external access and management
- Automatic firewall management per server type (TCP 25565 for Java, UDP 19132 for Bedrock)
- Pre-start sync script handles file/symlink setup from upstream to data directory

**TMux Integration:**
- Each server runs in a dedicated `tmux` session named `mc-${name}`
- TMux sockets are located at `/run/minecraft/${name}.sock` for external access
- Sessions remain active for command injection and log monitoring

## Development Commands

**Test module syntax:**
```bash
nix flake check
```

**Build/evaluate:**
```bash
nix eval .#nixosModules.nix-mc
```

## Configuration Patterns

**Server Definition Structure:**
- `type`: "forge" | "neoforge" | "bedrock"
- `upstreamDir`: Pre-installed server files (read-only)
- `dataDir`: Persistent runtime data (default: `/var/lib/minecraft/${name}`)
- `symlinks`: Directories to symlink (e.g., mods, config)
- `files`: Files/directories to copy on startup (e.g., server.properties)

**Security Model:**
- Services run as dedicated `minecraft` user/group
- Strict filesystem isolation via `ProtectSystem=strict`
- Only `dataDir` is writable
- No elevated privileges or capabilities

**Port Defaults:**
- Java servers (forge/neoforge): TCP 25565
- Bedrock servers: UDP 19132

## External Server Management

**Command Injection:**
Send commands to a running server using tmux:

```bash
# Send a server command
tmux -S /run/minecraft/${name}.sock send-keys -t mc-${name} "say Server message!" Enter

# Example: Say hello to players on "survival" server
tmux -S /run/minecraft/survival.sock send-keys -t mc-survival "say Hello players!" Enter

# Example: Stop the server gracefully
tmux -S /run/minecraft/survival.sock send-keys -t mc-survival "stop" Enter
```

**Log Monitoring:**
Access live server logs by attaching to the tmux session:

```bash
# Attach to view live output (detach with Ctrl+B then D)
tmux -S /run/minecraft/${name}.sock attach-session -t mc-${name}

# View session in read-only mode
tmux -S /run/minecraft/${name}.sock attach-session -t mc-${name} -r
```

**Log Persistence (Optional):**
Enable persistent logging to file:

```bash
# Enable pipe-pane for continuous log output
tmux -S /run/minecraft/${name}.sock pipe-pane -t mc-${name} -o "cat >> /var/log/minecraft-${name}.log"

# Disable pipe-pane
tmux -S /run/minecraft/${name}.sock pipe-pane -t mc-${name}
```

## Key Functions

- `mkSyncScript`: Generates pre-start script for file synchronization
- `mkService`: Creates systemd service configuration for servers with tmux integration
- `defaultsFor`: Provides type-specific defaults (ports, etc.)