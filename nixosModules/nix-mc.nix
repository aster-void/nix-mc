{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.minecraft;
  inherit (lib) mkEnableOption mkOption types mkIf mkMerge concatStringsSep mapAttrsToList;

  mkSyncScript = {
    dataDir,
    upstreamDir,
    symlinks,
    files,
  }: let
    # symlinks: { "mods" = "/srv/.../mods"; "config" = "/srv/.../config"; }
    symlinkScript =
      mapAttrsToList (dst: src: ''
        /run/current-system/sw/bin/ln -sfn ${lib.escapeShellArg src} ${lib.escapeShellArg "${dataDir}/${dst}"}
      '')
      symlinks;

    # destructiveCopy: for paths we want to mirror exactly from upstream (common for mods if not symlink)
    # (p may be contain "/"s so we must mkdir)
    filesScript =
      map (p: ''
        rm -rf -- ${lib.escapeShellArg "${dataDir}/${p}"} || true
        if [ -e ${lib.escapeShellArg "${upstreamDir}/${p}"} ]; then
          mkdir -p $(dirname ${lib.escapeShellArg "${dataDir}/${p}"})
          cp -a ${lib.escapeShellArg "${upstreamDir}/${p}"} ${lib.escapeShellArg "${dataDir}/${p}"}
        fi
      '')
      files;

    pre = concatStringsSep "\n" (filesScript ++ symlinkScript);
  in
    pre;

  # Defaults per server type
  defaultsFor = t: {
    ports =
      if t == "bedrock"
      then {
        tcp = [];
        udp = [19132];
      }
      else {
        tcp = [25565];
        udp = [];
      };
  };

  # Build a systemd service per server
  mkService = {
    name,
    serverCfg,
  }: let
    inherit (serverCfg) type dataDir upstreamDir environment extraExecStartArgs ExecStart ExecStartPre;

    exec = let
      # Forge/NeoForge: usually run.sh exists. Allow override via commandPath if provided.
      main =
        if ExecStart != null
        then ExecStart
        else if type == "bedrock"
        then ["${dataDir}/bedrock_server"]
        else ["${upstreamDir}/run.sh"];
      args =
        if extraExecStartArgs == null
        then []
        else extraExecStartArgs;
    in
      [main] ++ args;

    syncScrpit = mkSyncScript {
      inherit
        (serverCfg)
        dataDir
        upstreamDir
        symlinks
        files
        ;
    };
  in {
    description = "Minecraft ${type} server (${name})";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    inherit environment;
    path = [pkgs.coreutils pkgs.findutils pkgs.util-linux pkgs.gnugrep pkgs.gawk pkgs.diffutils];

    ExecStartPre =
      ExecStartPre
      ++ [
        syncScrpit
      ];
    ExecStart = exec;

    serviceConfig = {
      User = cfg.user;
      Group = cfg.group;
      StateDirectory = lib.removePrefix "/var/lib/" dataDir; # if under /var/lib, set as subdir; else ignored
      WorkingDirectory = dataDir;
      Restart = "on-failure";
      RestartSec = 2;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [dataDir];
      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
    };
  };
in {
  options.services.minecraft = {
    enable = mkEnableOption "simple Minecraft servers (Forge/NeoForge/Bedrock)";

    user = mkOption {
      type = types.str;
      default = "minecraft";
      description = "User to run servers as.";
    };
    group = mkOption {
      type = types.str;
      default = "minecraft";
      description = "Group for the user.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports per-server.";
    };

    servers = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };

          type = mkOption {
            type = types.enum ["forge" "neoforge" "bedrock"];
            description = "Server type.";
          };

          upstreamDir = mkOption {
            type = types.path;
            description = "Pre-installed upstream repository root (run.sh / libraries / bedrock_server etc.).";
          };

          dataDir = mkOption {
            type = types.path;
            default = "/var/lib/minecraft/${name}";
            description = "Persistent data directory (worlds/logs etc.).";
          };

          ExecStart = mkOption {
            type = types.nullOr types.path;
            default = null;
          };
          ExecStartPre = mkOption {
            type = types.nullOr types.str;
            default = null;
          };

          extraExecStartArgs = mkOption {
            type = types.listOf types.str;
            default = ["nogui"];
          };

          # Sync policy
          symlinks = mkOption {
            type = types.attrsOf types.path;
            default = {};
            description = "Symlink paths into dataDir (e.g., mods/config).";
          };
          files = mkOption {
            type = types.attrsOf types.path;
            default = {};
            description = "Copy files/dirs into dataDir (server.properties etc.).";
          };

          environment = mkOption {
            type = types.attrsOf types.str;
            default = {};
          };

          ports = mkOption {
            type = types.submodule {
              options = {
                tcp = mkOption {
                  type = types.listOf types.int;
                  default = (defaultsFor cfg.servers.${name}.type).ports.tcp;
                };
                udp = mkOption {
                  type = types.listOf types.int;
                  default = (defaultsFor cfg.servers.${name}.type).ports.udp;
                };
              };
            };
            default = {};
          };

          # Bedrock
          bedrock = mkOption {
            type = types.submodule {
              options = {
                worldName = mkOption {
                  type = types.str;
                  default = "BedrockLevel";
                };
              };
            };
            default = {};
          };
        };
      }));
      default = {};
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # ensure user and group exist
    {
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
      };
      users.groups.${cfg.group} = {};
    }

    # One systemd service per defined server
    (let
      mkOne = name: serverCfg: let
        svc = mkService {
          inherit name serverCfg;
        };
      in {
        systemd.services."minecraft-${name}" = {
          inherit (svc) description wantedBy after wants serviceConfig ExecStart ExecStartPre environment;
        };
        networking.firewall.allowedTCPPorts = mkIf (cfg.openFirewall && (serverCfg.ports.tcp != [])) serverCfg.ports.tcp;
        networking.firewall.allowedUDPPorts = mkIf (cfg.openFirewall && (serverCfg.ports.udp != [])) serverCfg.ports.udp;
      };
    in
      lib.mkMerge (lib.mapAttrsToList mkOne cfg.servers))
  ]);
}
