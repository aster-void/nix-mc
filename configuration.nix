# Minimal NixOS configuration for testing
{ config, pkgs, ... }:

{
  imports = [
    ./nixosModules/nix-mc.nix
  ];

  # Basic system requirements
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  
  # Test our minecraft module
  services.minecraft = {
    enable = true;
    openFirewall = true;
    servers.survival = {
      type = "forge";
      upstreamDir = "/opt/minecraft/forge-server";
      serverProperties = {
        "server-port" = 25565;
        "gamemode" = "survival";
        "difficulty" = "normal";
      };
    };
    servers.bedrock = {
      type = "bedrock"; 
      upstreamDir = "/opt/minecraft/bedrock-server";
    };
  };

  system.stateVersion = "23.11";
}