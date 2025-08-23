{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf mkMerge concatLines mapAttrsToList;

  toKV = k: v:
    if builtins.isBool v
    then "${k}=${lib.boolToString v}"
    else "${k}=${toString v}";

  mkSyncScript = {
    dataDir,
    symlinks,
    files,
    serverProperties ? null,
  }: let
    # symlinks: { "mods" = "${flake-input}/mods"; "config" = "${flake-input}/config"; }
    symlinkScript =
      mapAttrsToList (dst: src: ''
        /run/current-system/sw/bin/ln -sfn ${lib.escapeShellArg src} ${lib.escapeShellArg "${dataDir}/${dst}"}
      '')
      symlinks;

    # files copied with this method can be written (but it will be reset next launch)
    filesScript =
      map (p: ''
        rm -rf -- ${lib.escapeShellArg "${dataDir}/${p}"} || true
        if [ -e ${lib.escapeShellArg "${p}"} ]; then
          mkdir -p $(dirname ${lib.escapeShellArg "${dataDir}/${p}"})
          cp -a ${lib.escapeShellArg "${p}"} ${lib.escapeShellArg "${dataDir}/${p}"}
        fi
      '')
      files;

    # Generate server.properties if configured
    serverPropertiesScript =
      if serverProperties == null
      then []
      else [
        ''
          cat > ${lib.escapeShellArg "${dataDir}/server.properties"} << 'EOF'
          ${concatLines (mapAttrsToList toKV serverProperties)}
          EOF
        ''
      ];

    prePath =
      pkgs.writeShellScript "exec-start-pre"
      (lib.concatLines
        (filesScript
          ++ symlinkScript ++ serverPropertiesScript));
  in
    prePath;

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
    user,
    group,
  }: let
    inherit (serverCfg) type dataDir environment extraExecStartArgs ExecStart ExecStartPre symlinks files serverProperties;

    exec = let
      # Forge/NeoForge: usually run.sh exists. Allow override via commandPath if provided.
      main =
        if ExecStart != null
        then toString ExecStart
        else if type == "bedrock"
        then "${dataDir}/bedrock_server"
        else "./run.sh";
      args =
        if extraExecStartArgs == null
        then []
        else extraExecStartArgs;
    in
      lib.escapeShellArgs ([main] ++ args);

    syncScript = mkSyncScript {
      inherit
        dataDir
        symlinks
        files
        serverProperties
        ;
    };
  in {
    description = "Minecraft ${type} server (${name})";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    inherit environment;
    path = [
      pkgs.tmux
      pkgs.coreutils
      pkgs.bash
      pkgs.findutils
      pkgs.util-linux
      pkgs.gnugrep
      pkgs.gawk
      pkgs.diffutils
      pkgs.openjdk_headless
    ];

    serviceConfig = {
      User = user;
      Group = group;
      StateDirectory = lib.removePrefix "/var/lib/" dataDir; # if under /var/lib, set as subdir; else ignored
      WorkingDirectory = dataDir;
      Restart = "on-failure";
      RestartSec = 2;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [dataDir "/run/minecraft"];
      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
      ExecStartPre = ExecStartPre ++ [syncScript] ++ ["+${pkgs.coreutils}/bin/mkdir -p /run/minecraft"];
      ExecStart = "${pkgs.tmux}/bin/tmux -S /run/minecraft/${name}.sock new-session -s mc-${name} -c ${dataDir} -d ${exec}";
      ExecStopPost = "${pkgs.tmux}/bin/tmux -S /run/minecraft/${name}.sock kill-session -t mc-${name} || true";
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

          dataDir = mkOption {
            type = types.path;
            default = "/var/lib/minecraft/${name}";
            description = "Persistent data directory (worlds/logs etc.).";
          };
          serverProperties = mkOption {
            type = types.nullOr (types.attrsOf (types.oneOf [
              types.str
              types.int
              types.bool
            ]));
            default = null;
          };

          ExecStart = mkOption {
            type = types.nullOr types.path;
            default = null;
          };
          ExecStartPre = mkOption {
            type = types.listOf types.str;
            default = [];
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
            type = types.listOf types.str;
            default = [];
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
                  default = [];
                };
                udp = mkOption {
                  type = types.listOf types.int;
                  default = [];
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

  config = let
    minecraftCfg = config.services.minecraft;
  in
    mkIf minecraftCfg.enable (mkMerge [
      # ensure user and group exist
      {
        users.users.${minecraftCfg.user} = {
          isSystemUser = true;
          group = minecraftCfg.group;
        };
        users.groups.${minecraftCfg.group} = {};
        
        # Create runtime directory for tmux sockets
        systemd.tmpfiles.rules = [
          "d /run/minecraft 0755 ${minecraftCfg.user} ${minecraftCfg.group} -"
        ];
      }

      # One systemd service per defined server
      {
        systemd.services = lib.mapAttrs' (
          name: serverCfg: let
            svc = mkService {
              inherit name serverCfg;
              user = minecraftCfg.user;
              group = minecraftCfg.group;
            };
          in
            lib.nameValuePair "minecraft-${name}" {
              inherit (svc) description wantedBy after wants serviceConfig environment path;
            }
        ) (lib.filterAttrs (n: v: v.enable) minecraftCfg.servers);
      }

      # Firewall configuration
      (mkIf minecraftCfg.openFirewall {
        networking.firewall.allowedTCPPorts = lib.flatten (
          lib.mapAttrsToList (
            name: serverCfg: let
              defaults = (defaultsFor serverCfg.type).ports;
            in
              if serverCfg.ports.tcp != []
              then serverCfg.ports.tcp
              else defaults.tcp
          )
          minecraftCfg.servers
        );
        networking.firewall.allowedUDPPorts = lib.flatten (
          lib.mapAttrsToList (
            name: serverCfg: let
              defaults = (defaultsFor serverCfg.type).ports;
            in
              if serverCfg.ports.udp != []
              then serverCfg.ports.udp
              else defaults.udp
          )
          minecraftCfg.servers
        );
      })
    ]);
}
