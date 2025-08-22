# nix-mc

A NixOS module for running Minecraft servers (Forge, NeoForge, and Bedrock) with proper security hardening and file management.

> **Note**: For most use cases, consider using [nix-minecraft](https://github.com/Infinidoge/nix-minecraft) instead, which provides comprehensive Minecraft server management with automatic downloads and version management. Use nix-mc when you need to use mod loaders which are not supported by nix-minecraft or bedrock dedicated server.

## Features

- **Multiple Server Types**: Support for Forge, NeoForge, and Bedrock servers
- **Security Hardening**: Systemd services with `NoNewPrivileges`, `ProtectSystem=strict`, and restricted capabilities
- **Flexible File Management**: Configurable symlinks vs file copying for different content types
- **Multi-Server Support**: Run multiple server instances with individual configurations
- **Automatic Firewall**: Per-server firewall management with type-specific defaults

## Quick Start

1. Add this flake to your system configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-mc.url = "github:aster-void/nix-mc";
    
    # Version-locked server sources
    modpack-survival.url = "github:YourUsername/survival-mods/v1.0.0";
    modpack-survival.flake = false;

    forge-server.url = "github:YourUsername/forge-server-configs/1.20.1";
    forge-server.flake = false;
  };

  outputs = { nixpkgs, nix-mc, modpack-survival, forge-server, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        nix-mc.nixosModules.nix-mc
        # ... your other modules
      ];
    };
  };
}
```

2. Configure your servers in `configuration.nix`:

```nix
{ modpack-survival, forge-server, ... }: {
  services.minecraft = {
    enable = true;
    openFirewall = true;
    
    servers.survival = {
      type = "forge";
      upstreamDir = forge-server;  # Version-locked source
      symlinks = {
        mods = "${modpack-survival}/mods";
        config = "${modpack-survival}/config";
      };
      serverProperties = {
        "server-port" = 25565;
        difficulty = "normal";
        "max-players" = 20;
      };
    };
  };
}
```

## Usage Examples

### Basic Forge Server

```nix
# Using version-locked flake input
{ forge-server, modpack, ... }: {
  services.minecraft = {
    enable = true;
    openFirewall = true;
    
    servers.myserver = {
      type = "forge";
      upstreamDir = forge-server;
      symlinks = {
        mods = "${modpack}/mods";
        config = "${modpack}/config";
      };
    };
  };
}

# Alternative: Using fetchFromGitHub
{ pkgs, ... }: 
let
  forgeServer = pkgs.fetchFromGitHub {
    owner = "YourUsername";
    repo = "forge-server";
    rev = "v1.20.1";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in {
  services.minecraft = {
    enable = true;
    openFirewall = true;
    
    servers.myserver = {
      type = "forge";
      upstreamDir = forgeServer;
      symlinks = {
        mods = "${forgeServer}/mods";
        config = "${forgeServer}/config";
      };
    };
  };
}
```

### Bedrock Server

```nix
{ bedrock-server, ... }: {
  services.minecraft = {
    enable = true;
    openFirewall = true;
    
    servers.bedrock = {
      type = "bedrock";
      upstreamDir = bedrock-server;  # Version-locked source
      files = {
        "server.properties" = "${bedrock-server}/server.properties";
      };
      bedrock.worldName = "MyWorld";
    };
  };
}
```

### Multiple Servers

```nix
{ survival-server, creative-server, bedrock-server, ... }: {
  services.minecraft = {
    enable = true;
    openFirewall = true;
    
    servers = {
      survival = {
        type = "forge";
        upstreamDir = survival-server;  # Version-locked source
        ports.tcp = [ 25565 ];
      };
      
      creative = {
        type = "neoforge";
        upstreamDir = creative-server;  # Version-locked source
        ports.tcp = [ 25566 ];
      };
      
      bedrock = {
        type = "bedrock";
        upstreamDir = bedrock-server;  # Version-locked source
        ports.udp = [ 19132 ];
      };
    };
  };
}
```

## Version-Locked Server Sources

**✅ Recommended**: Use version-locked sources for reproducible, secure deployments:

### Benefits

- **Reproducibility**: Fully reproducible builds
- **Version Control**: Git commits, tags, releases
- **Atomic Updates**: Atomic flake updates
- **Rollbacks**: `nix flake lock --update-input`
- **Security**: Immutable store paths
- **CI/CD**: Consistent across environments

### Setup Guide

1. **Create a Git repository for server files**:
   ```bash
   git init minecraft-servers
   # Add your server files, mods, configs
   git add . && git commit -m "Initial server files"
   git tag v1.0.0
   ```

2. **Add to flake inputs**:
   ```nix
   inputs.minecraft-servers.url = "github:YourUsername/minecraft-servers/v1.0.0";
   inputs.minecraft-servers.flake = false;
   ```

3. **Use in configuration**:
   ```nix
   upstreamDir = inputs.minecraft-servers;
   ```

## Configuration Reference

### Global Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `services.minecraft.enable` | bool | `false` | Enable the Minecraft service |
| `services.minecraft.user` | string | `"minecraft"` | User to run servers as |
| `services.minecraft.group` | string | `"minecraft"` | Group for the user |
| `services.minecraft.openFirewall` | bool | `false` | Open firewall ports per-server |

### Server Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `type` | enum | - | Server type: `"forge"`, `"neoforge"`, or `"bedrock"` |
| `upstreamDir` | path | - | Pre-installed server files (read-only) |
| `dataDir` | path | `/var/lib/minecraft/${name}` | Persistent runtime data directory |
| `symlinks` | attrs | `{}` | Directories to symlink from upstream |
| `files` | attrs | `{}` | Files/directories to copy on startup |
| `serverProperties` | attrs | `null` | Auto-generate server.properties |
| `environment` | attrs | `{}` | Environment variables |
| `extraExecStartArgs` | list | `["nogui"]` | Additional command arguments |

### Port Configuration

| Server Type | Default Ports |
|-------------|---------------|
| Forge/NeoForge | TCP 25565 |
| Bedrock | UDP 19132 |

## File System Structure

### Project Layout

```
nix-mc/
├── flake.nix              # Flake entry point
├── flake.lock             # Locked dependencies
├── nixosModules/
│   └── nix-mc.nix         # Main NixOS module
├── CLAUDE.md              # Development guidance
└── README.md              # This file
```

### Runtime File Organization

```
/var/lib/minecraft/${name}/     # Server data directory (writable)
├── world/                      # World data (persistent)
├── logs/                       # Server logs (persistent)
├── server.properties          # Generated or copied config
├── mods/                       # Symlinked to upstreamDir/mods
├── config/                     # Symlinked to upstreamDir/config
└── ...                         # Other game files

/path/to/upstreamDir/           # Upstream server files (read-only)
├── run.sh                      # Server executable (Forge/NeoForge)
├── bedrock_server              # Server executable (Bedrock)
├── libraries/                  # Java libraries
├── mods/                       # Mod files
├── config/                     # Configuration templates
└── ...                         # Other server files
```

### Sync Strategy

The module uses two strategies for file management:

- **Symlinks** (`symlinks`): Creates symbolic links from `dataDir` to `upstreamDir`
  - Best for: mods, config, libraries (read-only content)
  - Advantages: No disk duplication, automatic updates

- **File Copy** (`files`): Copies files/directories on startup
  - Best for: server.properties, world templates (writable content)
  - Advantages: Independent modification, no upstream interference

## Security Model

- **Dedicated User**: Services run as `minecraft` user/group
- **Filesystem Isolation**: `ProtectSystem=strict` with read-only root filesystem
- **Limited Capabilities**: No elevated privileges or capabilities
- **Working Directory**: Restricted to `dataDir` only
- **Network Isolation**: Configurable firewall with type-specific defaults

## Development

Test the module syntax:
```bash
nix flake check
```

Evaluate the module:
```bash
nix eval .#nixosModules.nix-mc
```

## License

This project is provided as-is for educational and personal use.
